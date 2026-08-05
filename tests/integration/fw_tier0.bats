#!/usr/bin/env bats
# Integration tests for fw tier0 subcommand
#
# Tests the CLI interface for Tier 0 enforcement:
#   fw tier0          — show help
#   fw tier0 status   — show enforcement status

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

@test "fw tier0: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' tier0"
    [[ "$output" == *"tier0"* ]] || [[ "$output" == *"approve"* ]] || [[ "$output" == *"status"* ]]
}

# --- Status ---

@test "fw tier0 status: shows enforcement status" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' tier0 status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Tier 0"* ]] || [[ "$output" == *"tier0"* ]] || [[ "$output" == *"enforce"* ]] || [[ "$output" == *"status"* ]]
}
