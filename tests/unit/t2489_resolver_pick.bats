#!/usr/bin/env bats
# T-2489: `fw resolver pick` autonomously selects an eligible task for dispatch.
# The eligibility filter is the structural guard — the picker may only ever fire
# agent-owned, scoped, non-inception work. These tests pin the filter over
# fixtures (a synthetic active/ tree) and the dry-run surface contract.

load ../test_helper

setup() {
    PICKROOT="$(mktemp -d)"
    mkdir -p "$PICKROOT/.tasks/active" "$PICKROOT/.context/working" \
             "$PICKROOT/.context/project/workflows"
    # default workflow so dry-run can resolve a workflow name
    cat > "$PICKROOT/.context/project/workflows/default.yaml" <<'YAML'
task_type: default
worker_kind: TermLink
model: sonnet
prompt_template: prompts/default.md
strict_mcp_config: true
YAML
    cat > "$PICKROOT/.context/working/focus.yaml" <<'YAML'
current_task: T-9000
YAML
}

teardown() { rm -rf "$PICKROOT"; }

_task() {  # _task ID TYPE OWNER HORIZON STATUS AC
    local id="$1" type="$2" owner="$3" horizon="$4" status="$5" ac="$6"
    cat > "$PICKROOT/.tasks/active/${id}-x.md" <<EOF
---
id: ${id}
name: "fixture ${id}"
workflow_type: ${type}
owner: ${owner}
horizon: ${horizon}
status: ${status}
---

## Acceptance Criteria

### Agent
${ac}
EOF
}

_pick_json() {
    PROJECT_ROOT="$PICKROOT" python3 "$FRAMEWORK_ROOT/lib/resolver.py" pick --json
}

@test "t2489: eligible build task is picked; ineligible classes excluded with reasons" {
    _task T-1001 build      agent now started-work "- [ ] do the real thing"
    _task T-1002 inception  agent now started-work "- [ ] explore"
    _task T-1003 build      human now started-work "- [ ] human deliverable"
    _task T-1004 build      agent later started-work "- [ ] parked"
    _task T-1005 build      agent now captured     "- [ ] [First criterion]"
    _task T-9000 build      agent now started-work "- [ ] the focused task"

    run _pick_json
    [ "$status" -eq 0 ]
    # only T-1001 is eligible
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert d['pick']=='T-1001', d['pick']; \
assert d['eligible']==['T-1001'], d['eligible']; \
ex=d['excluded']; \
assert ex['T-1002'].startswith('workflow_type=inception'), ex; \
assert ex['T-1003']=='owner=human', ex; \
assert ex['T-1004']=='horizon=later', ex; \
assert ex['T-1005']=='placeholder/unscoped ACs', ex; \
assert 'focus' in ex['T-9000'], ex; \
assert d['dispatched'] is False; print('ok')"
}

@test "t2489: started-work ranks before captured, then oldest id first" {
    _task T-2002 build agent now captured     "- [ ] b"
    _task T-2001 build agent now started-work "- [ ] a"
    _task T-2003 build agent now started-work "- [ ] c"
    run _pick_json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert d['eligible']==['T-2001','T-2003','T-2002'], d['eligible']; \
assert d['pick']=='T-2001'; print('ok')"
}

@test "t2489: no eligible tasks → exit 0, pick null, not dispatched" {
    _task T-3001 inception agent now started-work "- [ ] explore"
    run _pick_json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert d['pick'] is None; assert d['dispatched'] is False; print('ok')"
}

@test "t2489: dry-run default never writes a dispatch row" {
    _task T-4001 build agent now started-work "- [ ] real work"
    PROJECT_ROOT="$PICKROOT" python3 "$FRAMEWORK_ROOT/lib/resolver.py" pick >/dev/null
    [ ! -f "$PICKROOT/.context/dispatches.jsonl" ]
}

@test "t2489: --dispatch fires the pick via resolve+spawn; exit 2 on worker error" {
    # In-process so we can inject a fake spawn BEFORE resolver's lazy import —
    # asserts the --dispatch wiring + exit-code parity with `run` without
    # firing a real worker.
    _task T-1001 build agent now started-work "- [ ] real work"
    cp "$PICKROOT/.context/working/focus.yaml" "$PICKROOT/.context/working/focus.yaml" 2>/dev/null || true
    printf 'current_task: T-0\n' > "$PICKROOT/.context/working/focus.yaml"
    mkdir -p "$PICKROOT/prompts"
    printf 'Task $TASK_ID\n$ACCEPTANCE_CRITERIA\n' > "$PICKROOT/prompts/default.md"
    printf 'task_type: default\nworker_kind: TermLink\nmodel: sonnet\nprompt_template: prompts/default.md\nstrict_mcp_config: true\ncwd: $PROJECT_ROOT\n' \
        > "$PICKROOT/.context/project/workflows/default.yaml"

    run env PROJECT_ROOT="$PICKROOT" FR="$FRAMEWORK_ROOT" python3 - <<'PY'
import os, sys, json, types, io, contextlib
fake = types.ModuleType("spawn")
class SpawnError(Exception): pass
fake.SpawnError = SpawnError
fake.spawn_dispatch = lambda env: {"status": "error", "events_count": 3,
    "events_path": "x", "terminal_event": {"type": "result", "is_error": True}}
sys.modules["spawn"] = fake
sys.path.insert(0, os.environ["FR"] + "/lib")
import resolver
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    rc = resolver.main(["pick", "--dispatch", "--json"])
out = json.loads(buf.getvalue())
assert rc == 2, rc
assert out["dispatched"] is True and out["pick"] == "T-1001", out
assert out["outcome"]["status"] == "error", out
print("ok")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *ok* ]]
}
