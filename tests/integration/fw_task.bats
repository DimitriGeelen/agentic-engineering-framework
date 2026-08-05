#!/usr/bin/env bats
# Integration tests for fw task subcommand
#
# Tests the CLI interface for task management:
#   fw task create   — create a new task
#   fw task update   — update task status
#   fw task list     — list active tasks

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" "$PROJECT_ROOT/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Create ---

@test "fw task create: creates a task file" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' task create --name 'Fix login timeout handling' --type build --owner agent --description 'Test description'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Task Created"* ]]
    # Task file should exist (any ID)
    local count
    count=$(ls "$PROJECT_ROOT/.tasks/active/"T-*-fix-login-timeout-handling.md 2>/dev/null | wc -l)
    [ "$count" -eq 1 ]
}

@test "fw task create: rejects placeholder names" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' task create --name 'Test task' --type build"
    [[ "$output" == *"placeholder"* ]] || [[ "$output" == *"template"* ]]
}

# --- Update ---

@test "fw task update: fails for nonexistent task" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' task update T-999 --status issues"
    [ "$status" -ne 0 ]
}

# --- List ---

@test "fw task: no subcommand shows help or lists tasks" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' task"
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"task"* ]]
}

@test "fw task list: shows active tasks" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' task create --name 'Visible task in list' --type build --owner agent --description 'Test'" > /dev/null 2>&1
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' task list"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Visible task"* ]] || [[ "$output" == *"T-"* ]]
}
