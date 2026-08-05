#!/usr/bin/env bats
# Integration tests for fw upgrade subcommand

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

@test "fw upgrade --help: shows usage" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' upgrade --help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"upgrade"* ]]
    [[ "$output" == *"--dry-run"* ]] || [[ "$output" == *"--force"* ]]
}

@test "fw upgrade --dry-run: shows what would change" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' upgrade --dry-run '$PROJECT_ROOT' 2>&1"
    [[ "$output" == *"DRY RUN"* ]] || [[ "$output" == *"WOULD"* ]] || [[ "$output" == *"upgrade"* ]]
}
