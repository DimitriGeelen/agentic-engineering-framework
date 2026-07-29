#!/usr/bin/env bats
# T-2675 — creation-side status invariant guard (companion to T-2674's owner
# leg; 832 rail-316: "two independent holes with separate root causes").
#
# create-task.sh only ever sets STATUS to the internal constants captured /
# started-work, so the is_valid_status guard is a never-fires invariant today.
# It exists so any future path that derives STATUS from less-trusted input
# (promote/ghost origins, a --status flag) dies before write. These tests pin
# (a) both live paths still write the expected valid status, (b) the guard is
# present in the script, (c) the predicate itself rejects out-of-enum values.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export TASKS_DIR="$TEST_TEMP_DIR/.tasks"
    export CONTEXT_DIR="$TEST_TEMP_DIR/.context"
    export NO_COLOR=1
    unset CLAUDECODE
    unset AI_AGENT

    mkdir -p "$TASKS_DIR/active" "$TASKS_DIR/completed" "$TASKS_DIR/templates"
    mkdir -p "$CONTEXT_DIR/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$TASKS_DIR/templates/" 2>/dev/null || true
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

run_create() {
    run "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" "$@"
}

@test "default create writes status: captured" {
    run_create --name "Status default probe" --type build --description "test" --owner agent
    [ "$status" -eq 0 ]
    grep -q "^status: captured$" "$TASKS_DIR"/active/T-*-status-default-probe.md
}

@test "--start create writes status: started-work" {
    run_create --name "Status start probe" --type build --description "test" --owner agent --start
    [ "$status" -eq 0 ]
    grep -q "^status: started-work$" "$TASKS_DIR"/active/T-*-status-start-probe.md
}

@test "guard call is present in create-task.sh before the write phase" {
    grep -q 'is_valid_status "\$STATUS"' "$FRAMEWORK_ROOT/agents/task-create/create-task.sh"
}

@test "is_valid_status rejects out-of-enum value (predicate behavior)" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' source '$FRAMEWORK_ROOT/lib/enums.sh' && is_valid_status bogus"
    [ "$status" -ne 0 ]
}

@test "is_valid_status accepts both internal constants" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' source '$FRAMEWORK_ROOT/lib/enums.sh' && is_valid_status captured && is_valid_status started-work"
    [ "$status" -eq 0 ]
}
