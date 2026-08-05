#!/usr/bin/env bats
# Integration tests for fw validate-init subcommand

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" "$PROJECT_ROOT/.tasks/templates"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    mkdir -p "$PROJECT_ROOT/.context/episodic" "$PROJECT_ROOT/.context/handovers"
    mkdir -p "$PROJECT_ROOT/.context/scans" "$PROJECT_ROOT/.context/bus" "$PROJECT_ROOT/.context/bus/blobs"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Validate ---

@test "fw validate-init: runs validation" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' validate-init"
    # May exit 1 if some optional checks fail in temp project
    [ "$status" -le 1 ]
    [[ "$output" == *"dir-"* ]] || [[ "$output" == *"Validation"* ]]
}

@test "fw validate-init: shows directory check results" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' validate-init"
    [ "$status" -le 1 ]
    [[ "$output" == *"dir-"* ]]
}
