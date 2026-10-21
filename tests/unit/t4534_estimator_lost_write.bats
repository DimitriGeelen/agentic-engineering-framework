#!/usr/bin/env bats
# T-4534: `fw inception decide` on a CAPTURED inception lost the started-work
# status write and then refused captured → work-completed (exit 1, task open).
#
# Root cause: update-task.sh fired the BVP estimator in the BACKGROUND before
# its own status sed. The estimator's whole-file read-modify-write read
# `status: captured`, and its later os.replace reverted the started-work write.
#
# Determinism: a sitecustomize shim, active only in estimator.py, delays the
# estimator's os.replace. Pre-fix, the
# delayed write lands after update-task.sh has returned, so the assertions
# below fail every time rather than on a lucky schedule.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export TASKS_DIR="$TEST_TEMP_DIR/.tasks"
    export CONTEXT_DIR="$TEST_TEMP_DIR/.context"
    export NO_COLOR=1
    unset CLAUDECODE
    export WATCHTOWER_URL="http://test.invalid:3000"

    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.tasks/completed" \
             "$TEST_TEMP_DIR/.context/working" "$TEST_TEMP_DIR/.context/episodic" \
             "$TEST_TEMP_DIR/.context/project" "$TEST_TEMP_DIR/shim"
    echo "id: TEST" > "$TEST_TEMP_DIR/.framework.yaml"

    cat > "$TEST_TEMP_DIR/shim/sitecustomize.py" <<'PY'
import os, sys, time
if sys.argv and sys.argv[0].endswith("estimator.py"):
    _replace = os.replace
    def _slow_replace(a, b, *k, **kw):
        time.sleep(float(os.environ.get("T4534_DELAY", "0")))
        return _replace(a, b, *k, **kw)
    os.replace = _slow_replace
PY
    export PYTHONPATH="$TEST_TEMP_DIR/shim${PYTHONPATH:+:$PYTHONPATH}"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_make_task() {
    local task_id="$1" status="$2" wtype="$3"
    cat > "$TEST_TEMP_DIR/.tasks/active/$task_id-test.md" <<EOF
---
id: $task_id
name: "T-4534 lost write"
status: $status
workflow_type: $wtype
owner: agent
horizon: now
created: 2026-10-21T00:00:00Z
last_update: 2026-10-21T00:00:00Z
---

# $task_id: T-4534 lost write

## Recommendation

**Recommendation:** NO-GO
**Rationale:** test
**Evidence:** test

## Acceptance Criteria

### Agent
- [x] All ticked

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Approve

## Decision

## Updates
EOF
}

@test "update-task started-work: estimator write is done (not in flight) when update-task returns" {
    _make_task T-9701 captured inception
    local f="$TEST_TEMP_DIR/.tasks/active/T-9701-test.md"
    export T4534_DELAY=2
    run bash "$AGENTS_DIR/task-create/update-task.sh" T-9701 --status started-work --skip-sovereignty --reason r
    [ "$status" -eq 0 ]
    # Pre-fix the estimator was still sleeping in the background here.
    grep -q '^bvp_scores_proposed:' "$f"
    grep -q '^status: started-work$' "$f"
    sleep 3
    # And nothing reverts it later.
    grep -q '^status: started-work$' "$f"
}

@test "inception decide on a CAPTURED inception closes it (no lost started-work write)" {
    _make_task T-9702 captured inception
    : > "$TEST_TEMP_DIR/.context/working/.reviewed-T-9702"
    export T4534_DELAY=2
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
    _decide_under_strict() {
        set -Eeuo pipefail
        do_inception_decide "$1" no-go --rationale "test" --i-am-human
    }
    run _decide_under_strict T-9702
    [ "$status" -eq 0 ]
    [[ "$output" != *"Invalid transition"* ]]
    [ -f "$TEST_TEMP_DIR/.tasks/completed/T-9702-test.md" ]
    grep -q '^status: work-completed$' "$TEST_TEMP_DIR/.tasks/completed/T-9702-test.md"
    sleep 3
    # No ghost recreated in active/ by a late estimator write.
    [ ! -e "$TEST_TEMP_DIR/.tasks/active/T-9702-test.md" ]
}

@test "estimator skips its write when the task file changed since it read it" {
    _make_task T-9703 started-work build
    local f="$TEST_TEMP_DIR/.tasks/active/T-9703-test.md"
    # Another writer edits the file inside write_proposed's read-modify-write
    # window (after its read, at the entry timestamp, before the replace).
    run python3 - "$AGENTS_DIR/termlink/bvp-estimator/estimator.py" "$f" <<'PY'
import importlib.util, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("estimator", sys.argv[1])
est = importlib.util.module_from_spec(spec)
spec.loader.exec_module(est)
task = Path(sys.argv[2])
_now, _done = est._utc_now, []
def _now_with_other_writer():
    if not _done:
        _done.append(1)
        task.write_text(task.read_text().replace("status: started-work", "status: work-completed"))
    return _now()
est._utc_now = _now_with_other_writer
print(est.write_proposed(task, {"D1": 3}, {}, "sha")[1])
print(est.write_proposed_cost(task, {"blast_radius": None, "tier": 2, "effort": 1}, {}, "sha")[1])
PY
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "file-changed-since-read" ]
    # The other writer's status change survives; nothing was clobbered.
    grep -q '^status: work-completed$' "$f"
    ! grep -q '^bvp_scores_proposed:' "$f" || false
}

@test "decide source: verifies the status after captured → started-work" {
    grep -q 'lost write, T-4534' "$FRAMEWORK_ROOT/lib/inception.sh"
}
