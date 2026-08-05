#!/usr/bin/env bats
# Integration tests for fw context subcommand
#
# Tests the CLI interface for context management:
#   fw context status — show context state
#   fw context init   — initialize session
#   fw context focus  — set/show current focus

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Init ---

@test "fw context init: initializes session" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context init"
    [ "$status" -eq 0 ]
    [ -f "$PROJECT_ROOT/.context/working/session.yaml" ]
}

# --- Focus ---

@test "fw context focus: shows no focus when none set" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context focus"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No"* ]] || [[ "$output" == *"no"* ]] || [[ "$output" == *"focus"* ]]
}

@test "fw context focus: sets focus on a task" {
    # Create a task first
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' task create --name 'Task for focus test' --type build --owner agent --description 'Test'" > /dev/null 2>&1
    # Find the task ID from the created file
    local task_id
    task_id=$(ls "$PROJECT_ROOT/.tasks/active/" | head -1 | grep -o 'T-[0-9]*')
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context focus '$task_id'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$task_id"* ]] || [[ "$output" == *"Focus"* ]] || [[ "$output" == *"focus"* ]]
}

# --- Help ---

@test "fw context: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context"
    [[ "$output" == *"usage"* ]] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"init"* ]] || [[ "$output" == *"status"* ]]
}
