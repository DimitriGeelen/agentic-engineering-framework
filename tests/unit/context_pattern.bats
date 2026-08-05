#!/usr/bin/env bats
# Unit tests for agents/context/lib/pattern.sh
#
# Tests the do_add_pattern() function:
#   - Pattern type validation (failure/success/workflow)
#   - ID generation with type-specific prefixes (FP/SP/WP)
#   - File creation and section appending
#   - Mitigation (failure patterns only)

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"

    # Disable colors for test output matching
    RED='' GREEN='' YELLOW='' CYAN='' NC=''

    # Stub ensure_context_dirs
    ensure_context_dirs() { mkdir -p "$CONTEXT_DIR/working" "$CONTEXT_DIR/project"; }
    export -f ensure_context_dirs

    # Source dependencies
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    source "$FRAMEWORK_ROOT/lib/compat.sh"
    source "$FRAMEWORK_ROOT/agents/context/lib/pattern.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Error handling ---

@test "add pattern: no args shows error" {
    run do_add_pattern
    [ "$status" -eq 1 ]
    [[ "$output" == *"Pattern type must be"* ]]
}

@test "add pattern: invalid type shows error" {
    run do_add_pattern "invalid" "My pattern"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Pattern type must be"* ]]
}

@test "add pattern: valid type but no name shows error" {
    run do_add_pattern "failure"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Pattern name required"* ]]
}

@test "add pattern: unknown option shows error" {
    run do_add_pattern "failure" "My pattern" --badopt value
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

# --- File creation ---

@test "add pattern: creates patterns.yaml when missing" {
    rm -f "$CONTEXT_DIR/project/patterns.yaml"
    run do_add_pattern "failure" "API timeout"
    [ "$status" -eq 0 ]
    [ -f "$CONTEXT_DIR/project/patterns.yaml" ]
}

# --- Failure patterns ---

@test "add pattern: failure pattern gets FP- prefix" {
    rm -f "$CONTEXT_DIR/project/patterns.yaml"
    run do_add_pattern "failure" "API timeout" --task T-100
    [ "$status" -eq 0 ]
    [[ "$output" == *"FP-001"* ]]
    [[ "$output" == *"failure"* ]]
}

@test "add pattern: failure pattern includes mitigation" {
    rm -f "$CONTEXT_DIR/project/patterns.yaml"
    run do_add_pattern "failure" "API timeout" --mitigation "Add retry logic"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Mitigation: Add retry logic"* ]]
    grep -q "mitigation" "$CONTEXT_DIR/project/patterns.yaml"
}

# --- Success patterns ---

@test "add pattern: success pattern gets SP- prefix" {
    rm -f "$CONTEXT_DIR/project/patterns.yaml"
    run do_add_pattern "success" "TDD approach" --task T-200
    [ "$status" -eq 0 ]
    [[ "$output" == *"SP-001"* ]]
    [[ "$output" == *"success"* ]]
}

# --- Workflow patterns ---

@test "add pattern: workflow pattern gets WP- prefix" {
    rm -f "$CONTEXT_DIR/project/patterns.yaml"
    run do_add_pattern "workflow" "Parallel investigation" --task T-300
    [ "$status" -eq 0 ]
    [[ "$output" == *"WP-001"* ]]
    [[ "$output" == *"workflow"* ]]
}

# --- Output ---

@test "add pattern: shows confirmation with pattern name" {
    rm -f "$CONTEXT_DIR/project/patterns.yaml"
    run do_add_pattern "failure" "Database connection lost"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Pattern added"* ]]
    [[ "$output" == *"Database connection lost"* ]]
}

@test "add pattern: shows task reference" {
    rm -f "$CONTEXT_DIR/project/patterns.yaml"
    run do_add_pattern "failure" "Timeout" --task T-999
    [ "$status" -eq 0 ]
    [[ "$output" == *"From: T-999"* ]]
}
