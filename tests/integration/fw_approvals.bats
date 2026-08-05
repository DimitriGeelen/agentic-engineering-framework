#!/usr/bin/env bats
# Integration tests for fw approvals subcommand

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    mkdir -p "$PROJECT_ROOT/.context/approvals"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Help ---

@test "fw approvals: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' approvals"
    [[ "$output" == *"approvals"* ]] || [[ "$output" == *"pending"* ]] || [[ "$output" == *"status"* ]]
}

# --- Pending ---

@test "fw approvals pending: runs with empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' approvals pending"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pending"* ]] || [[ "$output" == *"No"* ]] || [[ "$output" == *"0"* ]]
}

# --- Status ---

@test "fw approvals status: runs with empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' approvals status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Pending"* ]] || [[ "$output" == *"History"* ]] || [[ "$output" == *"none"* ]]
}
