#!/usr/bin/env bats
# T-2914: the autonomous resolver loop re-dispatched non-advancing tasks
# indefinitely (T-2862: 57 dispatches / 0 outcomes / unchanged for 2 days).
# These tests pin: (1) the stall guard excludes a task once N consecutive
# dispatches produced no measurable advancement, shown RED at --stall-after 0
# (today's default behaviour) vs GREEN once the guard is engaged; (2) each of
# the three advancement signals (status change / AC tick / landed commit)
# individually clears the stall flag; (3) `fw resolver stalled` surfaces
# dispatch_count + outcome_count so the exclusion is visible, not silent;
# (4) every dispatch row carries a non-null `origin`.

load ../test_helper

setup() {
    STALLROOT="$(mktemp -d)"
    mkdir -p "$STALLROOT/.tasks/active" "$STALLROOT/.context/working" \
             "$STALLROOT/.context/project/workflows" "$STALLROOT/prompts"
    cat > "$STALLROOT/.context/project/workflows/default.yaml" <<'YAML'
task_type: default
worker_kind: TermLink
model: sonnet
prompt_template: prompts/default.md
strict_mcp_config: true
YAML
    printf 'Task $TASK_ID\n$ACCEPTANCE_CRITERIA\n' > "$STALLROOT/prompts/default.md"
    printf 'current_task: null\n' > "$STALLROOT/.context/working/focus.yaml"
}

teardown() { rm -rf "$STALLROOT"; }

_task() {  # _task ID STATUS AC_BLOCK
    cat > "$STALLROOT/.tasks/active/${1}-x.md" <<EOF
---
id: ${1}
name: "fixture ${1}"
workflow_type: build
owner: agent
horizon: now
status: ${2}
---

## Acceptance Criteria

### Agent
${3}
EOF
}

# Seed N dispatch rows for a task, all sharing the same task_snapshot, spread
# a few minutes apart starting `age_min` minutes ago (oldest first).
_seed_dispatches() {  # _seed_dispatches TASK_ID N STATUS AC_TICKED AGE_MIN
    local tid="$1" n="$2" status="$3" ac_ticked="$4" age_min="$5"
    python3 - "$STALLROOT" "$tid" "$n" "$status" "$ac_ticked" "$age_min" <<'PY'
import sys, json, datetime
root, tid, n, status, ac_ticked, age_min = sys.argv[1:7]
n, ac_ticked, age_min = int(n), int(ac_ticked), int(age_min)
now = datetime.datetime.now(datetime.timezone.utc)
path = f"{root}/.context/dispatches.jsonl"
with open(path, "a") as f:
    for i in range(n):
        ts = (now - datetime.timedelta(minutes=age_min - i)).isoformat()
        row = {
            "schema_version": 1, "ts": ts, "dispatch_id": f"dd-{tid}-{i}",
            "task_id": tid, "task_type": "default", "worker_kind": "TermLink",
            "outcome": "success", "origin": "test-seed",
            "terminal_event": {"type": "result", "is_error": False},
            "task_snapshot": {"status": status, "ac_ticked": ac_ticked},
        }
        f.write(json.dumps(row) + "\n")
PY
}

_stalled() { PROJECT_ROOT="$STALLROOT" python3 "$FRAMEWORK_ROOT/lib/resolver.py" stalled "$@"; }
_loop() { PROJECT_ROOT="$STALLROOT" python3 "$FRAMEWORK_ROOT/lib/resolver.py" loop "$@"; }

@test "t2914: RED — with --stall-after 0 (old default) a 5x non-advancing task is still picked" {
    _task T-2862 started-work "- [ ] unfinished"
    _seed_dispatches T-2862 5 started-work 0 50
    run _loop --max 1 --stall-after 0 --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
ids=[p['id'] for p in d['picked']]; assert ids==['T-2862'], ids; print('ok')"
}

@test "t2914: GREEN — with --stall-after 5 the same 5x non-advancing task is excluded" {
    _task T-2862 started-work "- [ ] unfinished"
    _seed_dispatches T-2862 5 started-work 0 50
    run _loop --max 1 --stall-after 5 --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert d['picked']==[], d['picked']; print('ok')"
}

@test "t2914: 4 non-advancing dispatches (below threshold) still eligible at --stall-after 5" {
    _task T-2862 started-work "- [ ] unfinished"
    _seed_dispatches T-2862 4 started-work 0 50
    run _loop --max 1 --stall-after 5 --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
ids=[p['id'] for p in d['picked']]; assert ids==['T-2862'], ids; print('ok')"
}

@test "t2914: status change since the window clears the stall flag" {
    _task T-9101 started-work "- [ ] unfinished"
    _seed_dispatches T-9101 5 captured 0 50
    run _loop --max 1 --stall-after 5 --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
ids=[p['id'] for p in d['picked']]; assert ids==['T-9101'], ids; print('ok')"
}

@test "t2914: AC-ticked increase since the window clears the stall flag" {
    _task T-9102 started-work "- [x] done one
- [ ] unfinished"
    _seed_dispatches T-9102 5 started-work 0 50
    run _loop --max 1 --stall-after 5 --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
ids=[p['id'] for p in d['picked']]; assert ids==['T-9102'], ids; print('ok')"
}

@test "t2914: a landed commit referencing the task since the window clears the stall flag" {
    _task T-9103 started-work "- [ ] unfinished"
    _seed_dispatches T-9103 5 started-work 0 50
    ( cd "$STALLROOT" && git init -q && git config user.email t@t.test && \
      git config user.name t && git commit -q --allow-empty -m "T-9103: made progress" )
    run _loop --max 1 --stall-after 5 --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
ids=[p['id'] for p in d['picked']]; assert ids==['T-9103'], ids; print('ok')"
}

@test "t2914: fw resolver stalled surfaces dispatch_count and outcome_count" {
    _task T-2862 started-work "- [ ] unfinished"
    _seed_dispatches T-2862 5 started-work 0 50
    run _stalled --stall-after 5 --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
s=d['stalled']['T-2862']; assert s['dispatch_count']==5, s; \
assert s['outcome_count']==0, s; print('ok')"
}

@test "t2914: dispatch row carries non-null origin (env override)" {
    _task T-3001 started-work "- [ ] a"
    run env PROJECT_ROOT="$STALLROOT" FW_DISPATCH_ORIGIN="systemd:resolver-loop.service" \
        python3 "$FRAMEWORK_ROOT/lib/resolver.py" dispatch T-3001 default --json
    [ "$status" -eq 0 ]
    tail -1 "$STALLROOT/.context/dispatches.jsonl" | python3 -c "import sys,json; \
row=json.load(sys.stdin); assert row['origin']=='systemd:resolver-loop.service', row; print('ok')"
}

@test "t2914: dispatch row carries non-null origin (no env — falls back, never null)" {
    _task T-3002 started-work "- [ ] a"
    run env -u FW_DISPATCH_ORIGIN -u INVOCATION_ID PROJECT_ROOT="$STALLROOT" \
        python3 "$FRAMEWORK_ROOT/lib/resolver.py" dispatch T-3002 default --json </dev/null
    [ "$status" -eq 0 ]
    tail -1 "$STALLROOT/.context/dispatches.jsonl" | python3 -c "import sys,json; \
row=json.load(sys.stdin); assert row.get('origin'), row; print('ok:', row['origin'])"
}

@test "t2914: --cooldown-min default is 0 (no longer a same-as-interval no-op default)" {
    run env PROJECT_ROOT="$STALLROOT" python3 "$FRAMEWORK_ROOT/lib/resolver.py" loop --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"default 0"* ]]
}
