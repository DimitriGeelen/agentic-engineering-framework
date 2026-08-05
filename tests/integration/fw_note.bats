#!/usr/bin/env bats
# Integration tests for fw note subcommand

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

@test "fw note: no args shows usage" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' note"
    [[ "$output" == *"note"* ]] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"observation"* ]]
}

@test "fw note list: empty inbox" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' note list"
    [ "$status" -eq 0 ]
    [[ "$output" == *"empty"* ]] || [[ "$output" == *"no"* ]] || [[ "$output" == *"0"* ]]
}

@test "fw note: captures observation" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' note 'Test observation for integration test'"
    [[ "$output" == *"captured"* ]] || [[ "$output" == *"OBS-"* ]]
}
