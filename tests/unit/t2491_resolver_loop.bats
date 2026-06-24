#!/usr/bin/env bats
# T-2491: `fw resolver loop` — bounded autonomous dispatch driver. Calls the
# T-2489 picker up to --max times. Two new safety layers over single-shot pick:
# (1) an in-run `claimed` set so one invocation never re-picks the same task,
# (2) a --cooldown-min cross-tick anti-thrash guard. These tests pin
# boundedness, the dry-run no-write contract, cooldown exclusion, the claimed
# guard, and the paused cron registration.

load ../test_helper

setup() {
    LOOPROOT="$(mktemp -d)"
    mkdir -p "$LOOPROOT/.tasks/active" "$LOOPROOT/.context/working" \
             "$LOOPROOT/.context/project/workflows" "$LOOPROOT/prompts"
    cat > "$LOOPROOT/.context/project/workflows/default.yaml" <<'YAML'
task_type: default
worker_kind: TermLink
model: sonnet
prompt_template: prompts/default.md
strict_mcp_config: true
YAML
    printf 'Task $TASK_ID\n$ACCEPTANCE_CRITERIA\n' > "$LOOPROOT/prompts/default.md"
    printf 'current_task: null\n' > "$LOOPROOT/.context/working/focus.yaml"
}

teardown() { rm -rf "$LOOPROOT"; }

_task() {  # _task ID TYPE OWNER HORIZON STATUS AC
    cat > "$LOOPROOT/.tasks/active/${1}-x.md" <<EOF
---
id: ${1}
name: "fixture ${1}"
workflow_type: ${2}
owner: ${3}
horizon: ${4}
status: ${5}
---

## Acceptance Criteria

### Agent
${6}
EOF
}

_loop() {  # _loop ARGS...
    PROJECT_ROOT="$LOOPROOT" python3 "$FRAMEWORK_ROOT/lib/resolver.py" loop "$@"
}

@test "t2491: bounded — --max 2 picks exactly 2 distinct tasks from 5 eligible" {
    _task T-1001 build agent now started-work "- [ ] a"
    _task T-1002 build agent now started-work "- [ ] b"
    _task T-1003 build agent now started-work "- [ ] c"
    _task T-1004 build agent now started-work "- [ ] d"
    _task T-1005 build agent now started-work "- [ ] e"
    run _loop --max 2 --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
ids=[p['id'] for p in d['picked']]; \
assert len(ids)==2, ids; \
assert len(set(ids))==2, ids; \
assert all(p['dispatched'] is False for p in d['picked']); \
assert d['stop_reason'].startswith('reached --max'), d['stop_reason']; print('ok')"
}

@test "t2491: dry-run loop never writes a dispatch row" {
    _task T-2001 build agent now started-work "- [ ] real work"
    _loop --max 3 >/dev/null
    [ ! -f "$LOOPROOT/.context/dispatches.jsonl" ]
}

@test "t2491: --cooldown-min excludes a task dispatched within the window" {
    _task T-5001 build agent now started-work "- [ ] real work"
    # seed a completed dispatch row (terminal_event set → NOT in-flight) 1 min ago
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '{"task_id":"T-5001","ts":"%s","terminal_event":{"type":"result"}}\n' "$ts" \
        > "$LOOPROOT/.context/dispatches.jsonl"

    # cooldown 60m → excluded (cooling), nothing to pick
    run _loop --max 1 --cooldown-min 60 --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert d['picked']==[], d['picked']; print('ok')"

    # cooldown 0 → guard off, task is eligible again
    run _loop --max 1 --cooldown-min 0 --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
ids=[p['id'] for p in d['picked']]; assert ids==['T-5001'], ids; print('ok')"
}

@test "t2491: claimed set stops re-pick within one run even when spawn writes no row" {
    # In-process: fake spawn returns success but writes NO dispatch row. With one
    # eligible task and --max 3, only the `claimed` set can prevent re-picking it.
    _task T-1001 build agent now started-work "- [ ] real work"
    run env PROJECT_ROOT="$LOOPROOT" FR="$FRAMEWORK_ROOT" python3 - <<'PY'
import os, sys, json, types, io, contextlib
fake = types.ModuleType("spawn")
class SpawnError(Exception): pass
fake.SpawnError = SpawnError
fake.spawn_dispatch = lambda env: {"status": "ok", "events_count": 2,
    "events_path": "x", "terminal_event": {"type": "result", "is_error": False}}
sys.modules["spawn"] = fake
sys.path.insert(0, os.environ["FR"] + "/lib")
import resolver
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    rc = resolver.main(["loop", "--dispatch", "--max", "3", "--cooldown-min", "0", "--json"])
out = json.loads(buf.getvalue())
assert rc == 0, rc
ids = [p["id"] for p in out["picked"]]
assert ids == ["T-1001"], ids                       # dispatched once, not 3×
assert out["dispatched_count"] == 1, out
assert out["picked"][0]["dispatched"] is True, out
assert out["stop_reason"].startswith("no more eligible"), out["stop_reason"]
print("ok")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *ok* ]]
}

@test "t2491: cron entry resolver-loop-autonomous is registered PAUSED" {
    local reg="$FRAMEWORK_ROOT/.context/cron-registry.yaml"
    [ -f "$reg" ]
    run python3 -c "
import yaml,sys
d=yaml.safe_load(open('$reg')) or {}
jobs=d.get('jobs') or d.get('crons') or []
if isinstance(jobs,dict): jobs=list(jobs.values())
m=[j for j in jobs if str(j.get('id',j.get('name','')))=='resolver-loop-autonomous']
assert m, 'entry not found'
j=m[0]
cmd=str(j.get('command',j.get('cmd','')))
assert 'resolver loop' in cmd and '--dispatch' in cmd, cmd
paused = (j.get('enabled') is False) or (j.get('paused') is True) or (str(j.get('status','')).lower()=='paused')
assert paused, 'entry must be registered paused: '+str(j)
print('ok')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *ok* ]]
}
