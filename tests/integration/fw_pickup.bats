#!/usr/bin/env bats
# Integration tests for fw pickup subcommand
#
# Tests the full pickup pipeline through the fw CLI entry point.
# Unit tests in tests/unit/lib_pickup.bats cover internal functions.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    export NO_COLOR=1
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    mkdir -p "$PROJECT_ROOT/.context/pickup/inbox"
    mkdir -p "$PROJECT_ROOT/.context/pickup/processed"
    mkdir -p "$PROJECT_ROOT/.context/pickup/rejected"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_run_fw() {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' NO_COLOR=1 '$FW' pickup $*"
}

# --- Help ---

@test "fw pickup: no args shows help" {
    _run_fw ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw pickup"* ]]
    [[ "$output" == *"send"* ]]
    [[ "$output" == *"process"* ]]
    [[ "$output" == *"status"* ]]
    [[ "$output" == *"list"* ]]
}

@test "fw pickup --help: shows help" {
    _run_fw "--help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw pickup"* ]]
}

@test "fw pickup: unknown command fails" {
    _run_fw "bogus"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown pickup command"* ]]
}

# --- Status ---

@test "fw pickup status: shows counts" {
    _run_fw "status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Inbox:"* ]]
    [[ "$output" == *"Processed:"* ]]
    [[ "$output" == *"Rejected:"* ]]
}

# --- List ---

@test "fw pickup list: empty inbox" {
    _run_fw "list"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Inbox is empty"* ]]
}

# --- Send ---

@test "fw pickup send --help: shows usage" {
    _run_fw "send --help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw pickup send"* ]]
    [[ "$output" == *"--type"* ]]
    [[ "$output" == *"--summary"* ]]
}

@test "fw pickup send: requires --type" {
    _run_fw "send --summary 'test'"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--type is required"* ]]
}

@test "fw pickup send: requires --summary" {
    _run_fw "send --type bug-report"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--summary is required"* ]]
}

@test "fw pickup send: creates envelope" {
    _run_fw "send --type bug-report --summary 'Test bug' --source-project testproj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Created"* ]]
    [ -f "$PROJECT_ROOT/.context/pickup/inbox/P-001-bug-report.yaml" ]
}

@test "fw pickup send: envelope has correct fields" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' NO_COLOR=1 '$FW' pickup send --type learning --summary 'Use X not Y' --source-project myproj" >/dev/null
    local f="$PROJECT_ROOT/.context/pickup/inbox/P-001-learning.yaml"
    [ -f "$f" ]
    grep -q "type: learning" "$f"
    grep -q 'summary: "Use X not Y"' "$f"
    grep -q 'project: "myproj"' "$f"
}

@test "fw pickup list: shows envelope after send" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' NO_COLOR=1 '$FW' pickup send --type bug-report --summary 'Fix the widget' --source-project testproj" >/dev/null
    _run_fw "list"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Fix the widget"* ]]
    [[ "$output" == *"testproj"* ]]
}

# --- Process ---

@test "fw pickup process: empty inbox" {
    _run_fw "process"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Inbox is empty"* ]]
}

@test "fw pickup process --dry-run: shows what would be processed" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' NO_COLOR=1 '$FW' pickup send --type bug-report --summary 'Dry run test' --source-project testproj" >/dev/null
    _run_fw "process --dry-run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WOULD PROCESS"* ]]
    # File should still be in inbox
    [ -f "$PROJECT_ROOT/.context/pickup/inbox/P-001-bug-report.yaml" ]
}

@test "fw pickup status: counts update after send" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' NO_COLOR=1 '$FW' pickup send --type bug-report --summary 'Count test' --source-project testproj" >/dev/null
    _run_fw "status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Inbox:"* ]]
    # Should show at least 1 in inbox
    [[ "$output" == *"1"* ]]
}
