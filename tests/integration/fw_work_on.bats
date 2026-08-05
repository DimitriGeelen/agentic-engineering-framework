#!/usr/bin/env bats
# Integration tests for fw work-on command
#
# Tests the primary workflow entry point:
#   fw work-on "name" --type build   — create task + set focus + start
#   fw work-on T-XXX                 — resume existing task

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

# --- Create + Focus ---

@test "fw work-on: creates new task with name" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' work-on 'Fix auth timeout handling' --type build --owner agent --description 'Test task'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Task Created"* ]] || [[ "$output" == *"task"* ]] || [[ "$output" == *"T-"* ]]
    # Task file should exist
    local count
    count=$(ls "$PROJECT_ROOT/.tasks/active/"T-*-fix-auth-timeout-handling.md 2>/dev/null | wc -l)
    [ "$count" -eq 1 ]
}

@test "fw work-on: sets focus on new task" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' work-on 'Focus test task' --type build --owner agent --description 'Test'" > /dev/null 2>&1
    # Focus file should reference the task
    [ -f "$PROJECT_ROOT/.context/working/focus.yaml" ]
    local task_id
    task_id=$(ls "$PROJECT_ROOT/.tasks/active/" | head -1 | grep -o 'T-[0-9]*')
    run grep -q "$task_id" "$PROJECT_ROOT/.context/working/focus.yaml"
    [ "$status" -eq 0 ]
}

# --- Resume ---

@test "fw work-on: resumes existing task by ID" {
    # Create a task first
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' task create --name 'Resumable test task' --type build --owner agent --description 'Test'" > /dev/null 2>&1
    local task_id
    task_id=$(ls "$PROJECT_ROOT/.tasks/active/" | head -1 | grep -o 'T-[0-9]*')
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' work-on '$task_id'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$task_id"* ]]
}

@test "fw work-on: fails for nonexistent task ID" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' work-on T-9999"
    [ "$status" -ne 0 ]
}

# --- Help ---

@test "fw work-on: no arguments shows error or help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' work-on"
    # Should fail with usage info or error
    [[ "$output" == *"usage"* ]] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"work-on"* ]] || [ "$status" -ne 0 ]
}
