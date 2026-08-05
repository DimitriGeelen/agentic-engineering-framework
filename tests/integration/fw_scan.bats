#!/usr/bin/env bats
# Integration tests for fw scan subcommand

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    mkdir -p "$PROJECT_ROOT/.context/scans"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "fw scan: runs on empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' scan"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Scan written"* ]] || [[ "$output" == *"active"* ]] || [[ "$output" == *"completed"* ]]
}

@test "fw scan: creates scan file" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' scan" > /dev/null 2>&1
    ls "$PROJECT_ROOT/.context/scans/"SC-*.yaml 2>/dev/null | head -1
    [ "$(ls "$PROJECT_ROOT/.context/scans/"SC-*.yaml 2>/dev/null | wc -l)" -ge 1 ]
}
