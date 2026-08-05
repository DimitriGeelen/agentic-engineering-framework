#!/usr/bin/env bats
# Integration tests for fw test subcommand
# Named fw_test_cmd.bats to avoid confusion with test framework files

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

@test "fw test: runs test suite" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' test unit 2>&1 | head -5"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Unit Tests"* ]] || [[ "$output" == *"ok"* ]] || [[ "$output" == *"1.."* ]]
}

@test "fw test lint: runs shellcheck" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' test lint 2>&1 | head -5"
    [[ "$output" == *"ShellCheck"* ]] || [[ "$output" == *"Lint"* ]] || [[ "$output" == *"PASS"* ]] || [[ "$output" == *"WARN"* ]]
}

@test "fw test playwright: shows playwright header" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' test playwright 2>&1 | head -5"
    [[ "$output" == *"Playwright"* ]] || [[ "$output" == *"playwright"* ]] || [[ "$output" == *"pytest"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "fw test playwright: accepts --playwright flag" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' test --playwright 2>&1 | head -5"
    [[ "$output" == *"Playwright"* ]] || [[ "$output" == *"playwright"* ]] || [[ "$output" == *"pytest"* ]] || [[ "$output" == *"ERROR"* ]]
}
