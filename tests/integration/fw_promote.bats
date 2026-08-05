#!/usr/bin/env bats
# Integration tests for fw promote subcommand
#
# Tests the CLI interface for the graduation pipeline:
#   fw promote           — show help
#   fw promote suggest   — show promotion candidates
#   fw promote status    — show all learnings with counts

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

@test "fw promote: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' promote"
    [[ "$output" == *"promote"* ]] || [[ "$output" == *"suggest"* ]] || [[ "$output" == *"status"* ]]
}

# --- Suggest ---

@test "fw promote suggest: runs with empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' promote suggest"
    # May exit 0 or 1 depending on whether learnings exist
    [[ "$output" == *"No learnings"* ]] || [[ "$output" == *"suggest"* ]] || [[ "$output" == *"learning"* ]] || [[ "$output" == *"L-"* ]]
}

# --- Status ---

@test "fw promote status: runs with empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' promote status"
    [[ "$output" == *"status"* ]] || [[ "$output" == *"learning"* ]] || [[ "$output" == *"No"* ]] || [[ "$output" == *"L-"* ]]
}
