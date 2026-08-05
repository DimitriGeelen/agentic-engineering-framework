#!/usr/bin/env bats
# T-1559 — Regression: --skip-acceptance-criteria must bypass the AC check on
# the partial-complete recheck branch, not just the initial transition. Origin:
# pickup P-016 from 003-NTB-ATC-Plugin (T-225, C-018) — 20 tasks closed via
# manual checkbox-editing workaround in a single session. The auth flag is the
# marker of authorization; the file state is the artifact.

load ../test_helper

UPDATE_TASK="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" \
             "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" \
       "$PROJECT_ROOT/.tasks/templates/default.md" 2>/dev/null || \
       echo "# template" > "$PROJECT_ROOT/.tasks/templates/default.md"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a partial-complete task: status=work-completed, unchecked Human AC,
# satisfies recommendation gate (T-679) and RCA gate (T-1550, non-bug type).
_make_partial_task() {
    local id="$1"
    local task_file="$PROJECT_ROOT/.tasks/active/${id}-test-task.md"
    cat > "$task_file" <<EOF
---
id: $id
name: "Test partial-complete task"
description: "Test fixture for T-1559 regression"
status: work-completed
workflow_type: refactor
owner: agent
horizon: now
tags: []
created: 2026-04-27T00:00:00Z
last_update: 2026-04-27T00:00:00Z
date_finished: null
---

# $id: Test partial-complete task

## Acceptance Criteria

### Agent
- [x] Agent did the work

### Human
- [ ] [REVIEW] Human eyeballs it
  **Steps:**
  1. Look at it
  **Expected:** Looks good
  **If not:** Fix it

## Verification

## Recommendation

**Recommendation:** GO

**Rationale:** Test fixture.
EOF
    echo "$task_file"
}

@test "partial-complete recheck without --skip-acceptance-criteria: stays in active/" {
    _make_partial_task "T-9991"
    run "$UPDATE_TASK" T-9991 --status work-completed
    [ "$status" -eq 0 ]
    [[ "$output" == *"Still"* ]]
    [[ "$output" == *"unchecked"* ]]
    [ -f "$PROJECT_ROOT/.tasks/active/T-9991-test-task.md" ]
    [ ! -f "$PROJECT_ROOT/.tasks/completed/T-9991-test-task.md" ]
}

@test "partial-complete recheck with --skip-acceptance-criteria: archives to completed/" {
    _make_partial_task "T-9992"
    run "$UPDATE_TASK" T-9992 --status work-completed --skip-acceptance-criteria
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [[ "$output" == *"bypass"* ]]
    [ ! -f "$PROJECT_ROOT/.tasks/active/T-9992-test-task.md" ]
    [ -f "$PROJECT_ROOT/.tasks/completed/T-9992-test-task.md" ]
}

@test "partial-complete recheck with --skip-acceptance-criteria: bypass logged" {
    _make_partial_task "T-9993"
    run "$UPDATE_TASK" T-9993 --status work-completed --skip-acceptance-criteria
    [ "$status" -eq 0 ]
    local log="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
    [ -f "$log" ]
    grep -q "T-9993" "$log"
    grep -q "skip-acceptance-criteria" "$log"
    grep -q "partial_complete_recheck" "$log"
}

@test "partial-complete recheck: all-checked path still archives without flag" {
    _make_partial_task "T-9994"
    # Tick the human AC
    sed -i 's/- \[ \] \[REVIEW\]/- [x] [REVIEW]/' \
        "$PROJECT_ROOT/.tasks/active/T-9994-test-task.md"
    run "$UPDATE_TASK" T-9994 --status work-completed
    [ "$status" -eq 0 ]
    [[ "$output" == *"All ACs checked"* ]]
    [ -f "$PROJECT_ROOT/.tasks/completed/T-9994-test-task.md" ]
}
