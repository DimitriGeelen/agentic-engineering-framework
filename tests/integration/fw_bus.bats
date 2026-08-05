#!/usr/bin/env bats
# Integration tests for fw bus subcommand
#
# Tests the CLI interface for the task-scoped result ledger:
#   fw bus              — show help
#   fw bus post         — post a result
#   fw bus manifest     — show results summary
#   fw bus read         — read results
#   fw bus clear        — clear results

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    mkdir -p "$PROJECT_ROOT/.context/bus"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Help ---

@test "fw bus: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' bus"
    [[ "$output" == *"bus"* ]] || [[ "$output" == *"post"* ]] || [[ "$output" == *"manifest"* ]]
}

# --- Post ---

@test "fw bus post: posts a result" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' bus post --task T-999 --agent explore --summary 'Found 3 issues'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"R-"* ]] || [[ "$output" == *"posted"* ]] || [[ "$output" == *"T-999"* ]]
}

# --- Manifest ---

@test "fw bus manifest: shows results after post" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' bus post --task T-999 --agent explore --summary 'Test result'" > /dev/null 2>&1
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' bus manifest T-999"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-999"* ]] || [[ "$output" == *"explore"* ]] || [[ "$output" == *"Test result"* ]]
}

# --- Clear ---

@test "fw bus clear: clears results" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' bus post --task T-999 --agent explore --summary 'To be cleared'" > /dev/null 2>&1
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' bus clear T-999"
    [ "$status" -eq 0 ]
}
