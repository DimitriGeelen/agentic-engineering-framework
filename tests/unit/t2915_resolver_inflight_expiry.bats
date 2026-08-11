#!/usr/bin/env bats
# T-2915: the resolver's in-flight latch never expired — a dispatch row with
# no terminal_event excluded its task from the loop forever, because
# `_inflight_task_ids()` had no age bound. Nine tasks sat latched for five
# weeks with no distinguishing signal in `dispatched 0`. These tests pin the
# CLI-level surfaces: `fw resolver latched` (AC5, stale-latch visibility) and
# `fw resolver loop --json` naming its own silence (AC3).

load ../test_helper

setup() {
    IFROOT="$(mktemp -d)"
    mkdir -p "$IFROOT/.tasks/active" "$IFROOT/.context/working" \
             "$IFROOT/.context/project/workflows" "$IFROOT/prompts"
    cat > "$IFROOT/.context/project/workflows/default.yaml" <<'YAML'
task_type: default
worker_kind: TermLink
model: sonnet
prompt_template: prompts/default.md
strict_mcp_config: true
YAML
    printf 'Task $TASK_ID\n$ACCEPTANCE_CRITERIA\n' > "$IFROOT/prompts/default.md"
    printf 'current_task: null\n' > "$IFROOT/.context/working/focus.yaml"
}

teardown() { rm -rf "$IFROOT"; }

_task() {  # _task ID STATUS AC_BLOCK
    cat > "$IFROOT/.tasks/active/${1}-x.md" <<EOF
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

# Seed a single dispatch row with NO terminal_event, `age_min` minutes old —
# simulates a worker that never reported back (crash, OOM, host reboot).
_seed_open() {  # _seed_open TASK_ID AGE_MIN
    local tid="$1" age_min="$2"
    python3 - "$IFROOT" "$tid" "$age_min" <<'PY'
import sys, json, datetime
root, tid, age_min = sys.argv[1], sys.argv[2], float(sys.argv[3])
now = datetime.datetime.now(datetime.timezone.utc)
ts = (now - datetime.timedelta(minutes=age_min)).isoformat()
row = {
    "schema_version": 1, "ts": ts, "dispatch_id": f"dd-{tid}",
    "task_id": tid, "task_type": "default", "worker_kind": "TermLink",
    "outcome": None, "origin": "test-seed",
}
with open(f"{root}/.context/dispatches.jsonl", "a") as f:
    f.write(json.dumps(row) + "\n")
PY
}

_latched() { PROJECT_ROOT="$IFROOT" python3 "$FRAMEWORK_ROOT/lib/resolver.py" latched "$@"; }
_loop() { PROJECT_ROOT="$IFROOT" python3 "$FRAMEWORK_ROOT/lib/resolver.py" loop "$@"; }
_pick() { PROJECT_ROOT="$IFROOT" python3 "$FRAMEWORK_ROOT/lib/resolver.py" pick "$@"; }

@test "t2915: a dispatch row within the age bound still excludes its task (in-flight)" {
    _task T-9301 started-work "- [ ] unfinished"
    _seed_open T-9301 10
    run _pick --json --stall-after 0
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
excl=dict(d['excluded']); assert excl.get('T-9301')=='in-flight dispatch', excl; print('ok')"
}

@test "t2915: a dispatch row beyond the age bound (FW_RESOLVER_INFLIGHT_MAX_AGE_MIN) is re-eligible" {
    _task T-9302 started-work "- [ ] unfinished"
    _seed_open T-9302 90
    run env PROJECT_ROOT="$IFROOT" FW_RESOLVER_INFLIGHT_MAX_AGE_MIN=60 \
        python3 "$FRAMEWORK_ROOT/lib/resolver.py" pick --json --stall-after 0
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert 'T-9302' in d['eligible'], d; print('ok')"
}

@test "t2915: fw resolver latched surfaces the stale row and not the fresh one" {
    _task T-9303 started-work "- [ ] unfinished"
    _task T-9304 started-work "- [ ] unfinished"
    _seed_open T-9303 500   # well beyond default 240min bound
    _seed_open T-9304 10    # well within it
    run _latched --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
lat=d['latched']; assert 'T-9303' in lat, lat; assert 'T-9304' not in lat, lat; print('ok')"
}

@test "t2915: fw resolver latched --json prints empty map when nothing is stale" {
    _task T-9305 started-work "- [ ] unfinished"
    _seed_open T-9305 5
    run _latched --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert d['latched']=={}, d; print('ok')"
}

@test "t2915: loop --json names the in-flight count when that is the only exclusion" {
    _task T-9306 started-work "- [ ] unfinished"
    _seed_open T-9306 10   # fresh — still in-flight, the ONLY active task
    run _loop --max 1 --json --stall-after 0
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert d['picked']==[], d; assert d['in_flight_count']==1, d; \
assert 'in-flight' in d['stop_reason'], d['stop_reason']; print('ok')"
}

@test "t2915: loop --json distinguishes nothing-to-do from in-flight" {
    # No active tasks at all — the loop's silence must not read the same
    # as the in-flight case above.
    run _loop --max 1 --json --stall-after 0
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert d['picked']==[], d; assert d['in_flight_count']==0, d; \
assert 'nothing to do' in d['stop_reason'], d['stop_reason']; \
assert 'in-flight' not in d['stop_reason'], d['stop_reason']; print('ok')"
}
