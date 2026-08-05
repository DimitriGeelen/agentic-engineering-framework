#!/usr/bin/env bats
# Integration tests for fw self-audit subcommand

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

@test "fw self-audit: runs audit report" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' self-audit"
    [[ "$output" == *"SELF-AUDIT"* ]] || [[ "$output" == *"LAYER"* ]] || [[ "$output" == *"PASS"* ]] || [[ "$output" == *"FAIL"* ]]
}

@test "fw self-audit: checks foundation layer" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' self-audit"
    [[ "$output" == *"FOUNDATION"* ]] || [[ "$output" == *"bin/fw"* ]] || [[ "$output" == *"FRAMEWORK"* ]]
}
