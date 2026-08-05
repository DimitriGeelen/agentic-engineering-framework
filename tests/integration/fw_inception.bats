#!/usr/bin/env bats
# Integration tests for fw inception subcommand
#
# Tests the CLI interface for inception workflow:
#   fw inception           — show help
#   fw inception status    — list inception tasks
#   fw inception start     — create inception task

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Help ---

@test "fw inception: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' inception"
    [[ "$output" == *"inception"* ]] || [[ "$output" == *"start"* ]] || [[ "$output" == *"status"* ]]
}

# --- Status ---

@test "fw inception status: runs with empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' inception status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"inception"* ]] || [[ "$output" == *"No"* ]]
}

# --- Start ---

@test "fw inception start: creates inception task" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' inception start 'Evaluate caching strategy'"
    [ "$status" -eq 0 ]
    # Task file should exist with inception type
    local count
    count=$(ls "$PROJECT_ROOT/.tasks/active/"T-*-evaluate-caching-strategy.md 2>/dev/null | wc -l)
    [ "$count" -eq 1 ]
}

@test "fw inception start: task has inception workflow type" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' inception start 'Test workflow type'" > /dev/null 2>&1
    local task_file
    task_file=$(ls "$PROJECT_ROOT/.tasks/active/"T-*-test-workflow-type.md 2>/dev/null | head -1)
    [ -n "$task_file" ]
    run grep "workflow_type: inception" "$task_file"
    [ "$status" -eq 0 ]
}

@test "fw inception status: shows created inception task" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' inception start 'Status check task'" > /dev/null 2>&1
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' inception status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Status check"* ]] || [[ "$output" == *"T-"* ]]
}
