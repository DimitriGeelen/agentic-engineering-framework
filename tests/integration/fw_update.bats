#!/usr/bin/env bats
# Integration tests for fw update subcommand

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

@test "fw update --help: shows usage" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' update --help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update"* ]]
    [[ "$output" == *"--check"* ]] || [[ "$output" == *"--branch"* ]] || [[ "$output" == *"--rollback"* ]]
}

@test "fw update --check: shows version info" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' update --check 2>&1"
    # May fail on network, but should at least show version info
    [[ "$output" == *"Framework"* ]] || [[ "$output" == *"Current"* ]] || [[ "$output" == *"update"* ]]
}
