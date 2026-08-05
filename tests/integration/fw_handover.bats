#!/usr/bin/env bats
# Integration tests for fw handover subcommand
#
# Tests the CLI interface for session handover:
#   fw handover            — generate handover document
#   fw handover --help     — show help
#   fw handover --no-commit — generate without committing

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
    # Initialize a git repo for handover commit
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

@test "fw handover --help: shows usage" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' handover --help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"handover"* ]]
}

# --- Generate ---

@test "fw handover --no-commit: creates handover file" {
    # Initialize session first
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context init" > /dev/null 2>&1
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' handover --no-commit"
    [ "$status" -eq 0 ]
    [ -f "$PROJECT_ROOT/.context/handovers/LATEST.md" ]
}

@test "fw handover --no-commit: handover contains expected sections" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context init" > /dev/null 2>&1
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' handover --no-commit" > /dev/null 2>&1
    run grep -c "^##" "$PROJECT_ROOT/.context/handovers/LATEST.md"
    # Should have multiple sections
    [ "$output" -ge 2 ]
}

@test "fw handover --no-commit: output mentions handover created" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' context init" > /dev/null 2>&1
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' handover --no-commit"
    [[ "$output" == *"Handover"* ]] || [[ "$output" == *"handover"* ]] || [[ "$output" == *"Created"* ]]
}
