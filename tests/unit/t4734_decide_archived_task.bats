#!/usr/bin/env bats
# T-4734: `fw inception decide` on a task that lives in .tasks/completed/ must say
# it is archived and point at `fw inception correct` (T-4324), not claim the task
# is "not found in active tasks". A task id that exists nowhere keeps "not found".

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

    mkdir -p "$TASKS_DIR/active" "$TASKS_DIR/completed" "$CONTEXT_DIR/working"
    echo "id: TEST" > "$TEST_TEMP_DIR/.framework.yaml"

    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/lib/task-audit.sh"
    source "$FRAMEWORK_ROOT/lib/inception.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_make_completed() {
    local task_id="$1" wf="$2"
    cat > "$TASKS_DIR/completed/$task_id-done.md" <<EOT
---
id: $task_id
name: "Archived task"
status: work-completed
workflow_type: $wf
owner: agent
---

## Decision

**Decision**: GO
EOT
}

@test "decide on a completed inception names it archived and points at inception correct" {
    _make_completed T-9901 inception
    run do_inception_decide T-9901 no-go --rationale "wrong verdict" --i-am-human
    [ "$status" -ne 0 ]
    [[ "$output" == *"archived"* ]]
    [[ "$output" == *".tasks/completed/"* ]]
    [[ "$output" == *"inception correct T-9901"* ]]
    [[ "$output" != *"not found in active tasks"* ]]
    [[ "$output" != *"mv "* ]]
}

@test "decide on a completed non-inception names it archived without suggesting correct" {
    _make_completed T-9902 build
    run do_inception_decide T-9902 go --rationale "x" --i-am-human
    [ "$status" -ne 0 ]
    [[ "$output" == *"archived"* ]]
    [[ "$output" != *"inception correct"* ]]
}

@test "decide on a task id that exists nowhere still says not found" {
    run do_inception_decide T-9903 go --rationale "x" --i-am-human
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
    [[ "$output" != *"archived"* ]]
}
