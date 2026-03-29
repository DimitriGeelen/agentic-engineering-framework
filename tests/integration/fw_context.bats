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
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Status ---

@test "fw context status: shows context state" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CONTEXT"* ]] || [[ "$output" == *"context"* ]] || [[ "$output" == *"Memory"* ]]
}

@test "fw context status: shows working memory section" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WORKING"* ]] || [[ "$output" == *"Working"* ]] || [[ "$output" == *"session"* ]]
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

@test "fw context focus T-001: sets focus" {
    # Create a task first
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' task create --name 'Task for focus test' --type build --owner agent --description 'Test'" > /dev/null
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context focus T-001"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-001"* ]] || [[ "$output" == *"Focus"* ]] || [[ "$output" == *"focus"* ]]
}

# --- Help ---

@test "fw context: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context"
    [[ "$output" == *"usage"* ]] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"init"* ]] || [[ "$output" == *"status"* ]]
}
