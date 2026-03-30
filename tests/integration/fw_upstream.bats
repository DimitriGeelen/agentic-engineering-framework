#!/usr/bin/env bats
# Integration tests for fw upstream subcommand

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "fw upstream: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' upstream"
    [[ "$output" == *"upstream"* ]] || [[ "$output" == *"config"* ]] || [[ "$output" == *"report"* ]]
}

@test "fw upstream config: shows configuration" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' upstream config"
    [[ "$output" == *"Upstream"* ]] || [[ "$output" == *"Configuration"* ]] || [[ "$output" == *"Repo"* ]]
}
