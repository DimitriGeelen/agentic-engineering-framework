#!/usr/bin/env bats
# Integration tests for fw resume subcommand
#
# Tests the CLI interface for session recovery:
#   fw resume status  — full state synthesis
#   fw resume sync    — fix stale working memory
#   fw resume quick   — one-line summary

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    mkdir -p "$PROJECT_ROOT/.context/handovers" "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    # Initialize a git repo
    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" config user.email "test@test.com"
    git -C "$PROJECT_ROOT" config user.name "Test"
    echo "init" > "$PROJECT_ROOT/init.txt"
    git -C "$PROJECT_ROOT" add -A
    git -C "$PROJECT_ROOT" commit -q -m "Initial commit"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Help ---

@test "fw resume: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' resume"
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"status"* ]] || [[ "$output" == *"resume"* ]]
}

# --- Quick ---

@test "fw resume quick: shows summary line" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' resume quick"
    [ "$status" -eq 0 ]
}

# --- Status ---

@test "fw resume status: runs without error" {
    # Create session state for status to read
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context init" > /dev/null 2>&1
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' resume status"
    [ "$status" -eq 0 ]
}

# --- Sync ---

@test "fw resume sync: runs without error" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context init" > /dev/null 2>&1
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' resume sync"
    [ "$status" -eq 0 ]
}

@test "fw resume sync: updates session file" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context init" > /dev/null 2>&1
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' resume sync" > /dev/null 2>&1
    [ -f "$PROJECT_ROOT/.context/working/session.yaml" ]
}
