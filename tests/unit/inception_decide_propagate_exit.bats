#!/usr/bin/env bats
# T-1515: do_inception_decide must capture and propagate update-task.sh exit codes.
# T-1491 RCA: prior code discarded the exit code, so a P-010/P-011 failure left
# the task in class 2 stuck state (started-work + Decision recorded) while the
# user saw "Inception decision recorded" and the function returned 0. T-1514's
# sweep extension recovers this state retroactively; this test guards the
# prevention.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    # Stub AGENTS_DIR with a fake update-task.sh we control
    export AGENTS_DIR="$TEST_TEMP_DIR/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export NO_COLOR=1
    unset CLAUDECODE
    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.context/working"
    mkdir -p "$AGENTS_DIR/task-create"

    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_make_task() {
    local task_id="$1"
    local f="$TEST_TEMP_DIR/.tasks/active/$task_id-test.md"
    : > "$TEST_TEMP_DIR/.context/working/.reviewed-$task_id"
    cat > "$f" <<EOF
---
id: $task_id
name: "Test inception"
status: started-work
workflow_type: inception
owner: agent
horizon: now
created: 2026-04-26T00:00:00Z
last_update: 2026-04-26T00:00:00Z
---

# $task_id: Test inception

## Recommendation

**Recommendation:** GO
**Rationale:** test
**Evidence:** test

## Acceptance Criteria

### Agent
- [x] All auto-tick ACs satisfied

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:** etc.

## Decision

## Updates
EOF
    echo "$f"
}

_stub_update_task_failing() {
    cat > "$AGENTS_DIR/task-create/update-task.sh" <<'STUB'
#!/usr/bin/env bash
echo "stub update-task.sh: simulated P-010 AC gate failure" >&2
exit 7
STUB
    chmod +x "$AGENTS_DIR/task-create/update-task.sh"
}

_stub_update_task_succeeding() {
    cat > "$AGENTS_DIR/task-create/update-task.sh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
    chmod +x "$AGENTS_DIR/task-create/update-task.sh"
}

@test "exit propagation: failing update-task.sh causes non-zero return + error guidance" {
    local task_id="T-9601"
    _make_task "$task_id"
    _stub_update_task_failing

    run do_inception_decide "$task_id" go --rationale "test" --i-am-human

    [ "$status" -ne 0 ]
    [[ "$output" == *"status transition started-work→work-completed failed"* ]]
    [[ "$output" == *"inception sweep"* ]]
    [[ "$output" == *"task verify"* ]]
    # CRITICAL: success line must NOT appear
    [[ "$output" != *"Inception decision recorded"* ]]
}

@test "exit propagation: succeeding update-task.sh preserves success path" {
    local task_id="T-9602"
    _make_task "$task_id"
    _stub_update_task_succeeding

    run do_inception_decide "$task_id" go --rationale "test" --i-am-human

    [ "$status" -eq 0 ]
    [[ "$output" == *"Inception decision recorded"* ]]
    [[ "$output" != *"status transition"*"failed"* ]]
}

@test "exit propagation: exit code from update-task.sh is propagated verbatim" {
    local task_id="T-9603"
    _make_task "$task_id"
    cat > "$AGENTS_DIR/task-create/update-task.sh" <<'STUB'
#!/usr/bin/env bash
exit 13
STUB
    chmod +x "$AGENTS_DIR/task-create/update-task.sh"

    run do_inception_decide "$task_id" go --rationale "test" --i-am-human
    [ "$status" -eq 13 ]
}
