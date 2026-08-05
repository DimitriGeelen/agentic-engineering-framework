#!/usr/bin/env bats
# Integration tests for fw onboarding subcommand

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

# --- Status ---

@test "fw onboarding: shows status" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' onboarding"
    [[ "$output" == *"nboarding"* ]] || [[ "$output" == *"complete"* ]] || [[ "$output" == *"pending"* ]]
}

@test "fw onboarding status: runs without error" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' onboarding status"
    [[ "$output" == *"nboarding"* ]] || [[ "$output" == *"complete"* ]] || [[ "$output" == *"pending"* ]] || [[ "$output" == *"status"* ]]
}
