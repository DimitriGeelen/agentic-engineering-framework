#!/usr/bin/env bats
# Integration tests for fw doctor subcommand
#
# Tests the CLI interface for framework health check:
#   fw doctor — run all health checks

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

# --- Basic ---

@test "fw doctor: runs without fatal error" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' doctor 2>&1"
    # 0 = all OK, non-zero = warnings/failures but not crash
    [[ "$output" == *"doctor"* ]] || [[ "$output" == *"OK"* ]] || [[ "$output" == *"WARN"* ]]
}

@test "fw doctor: checks framework installation" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' doctor 2>&1"
    [[ "$output" == *"Framework installation"* ]] || [[ "$output" == *"installation"* ]]
}

@test "fw doctor: checks .framework.yaml" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' doctor 2>&1"
    [[ "$output" == *".framework.yaml"* ]]
}

@test "fw doctor: shows OK or WARN status markers" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' doctor 2>&1"
    [[ "$output" == *"OK"* ]] || [[ "$output" == *"WARN"* ]] || [[ "$output" == *"SKIP"* ]]
}
