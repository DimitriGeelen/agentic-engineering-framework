#!/usr/bin/env bats
# Integration tests for fw dispatch subcommand

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

@test "fw dispatch: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' dispatch"
    [[ "$output" == *"dispatch"* ]] || [[ "$output" == *"send"* ]] || [[ "$output" == *"hosts"* ]]
}

@test "fw dispatch send: missing args shows error" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' dispatch send 2>&1"
    [[ "$output" == *"--host"* ]] || [[ "$output" == *"required"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "fw dispatch approve: creates approval window" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' dispatch approve"
    [ "$status" -eq 0 ]
    [[ "$output" == *"approved"* ]] || [[ "$output" == *"dispatch"* ]]
}

@test "fw dispatch reset: resets counter" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' dispatch reset"
    [ "$status" -eq 0 ]
    [[ "$output" == *"reset"* ]] || [[ "$output" == *"dispatch"* ]]
}
