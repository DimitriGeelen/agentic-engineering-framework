#!/usr/bin/env bats
# Integration tests for fw assumption subcommand
#
# Tests the CLI interface for assumption tracking:
#   fw assumption           — show help
#   fw assumption add       — register an assumption
#   fw assumption list      — list assumptions
#   fw assumption validate  — mark as validated

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

@test "fw assumption: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' assumption"
    [[ "$output" == *"assumption"* ]] || [[ "$output" == *"add"* ]] || [[ "$output" == *"list"* ]]
}

# --- Add ---

@test "fw assumption add: registers an assumption" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' assumption add 'Users want notifications' --task T-999"
    [ "$status" -eq 0 ]
    [[ "$output" == *"A-"* ]]
}

# --- List ---

@test "fw assumption list: runs with empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' assumption list"
    [ "$status" -eq 0 ]
}

@test "fw assumption list: shows added assumption" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' assumption add 'Test assumption for listing' --task T-999" > /dev/null 2>&1
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' assumption list"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test assumption"* ]] || [[ "$output" == *"A-"* ]]
}
