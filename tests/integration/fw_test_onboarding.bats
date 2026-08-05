#!/usr/bin/env bats
# Integration tests for fw test-onboarding subcommand

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

@test "fw test-onboarding: runs onboarding test" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' test-onboarding 2>&1"
    [[ "$output" == *"ONBOARDING"* ]] || [[ "$output" == *"CHECKPOINT"* ]] || [[ "$output" == *"PASS"* ]]
}

@test "fw test-onboarding: checks project scaffold" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' test-onboarding 2>&1"
    [[ "$output" == *"SCAFFOLD"* ]] || [[ "$output" == *"init"* ]] || [[ "$output" == *"directories"* ]]
}
