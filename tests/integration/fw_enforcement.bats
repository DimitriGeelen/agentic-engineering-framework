#!/usr/bin/env bats
# Integration tests for fw enforcement subcommand

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

@test "fw enforcement: shows enforcement status" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' enforcement"
    [ "$status" -eq 0 ]
    [[ "$output" == *"enforcement"* ]] || [[ "$output" == *"Layer"* ]] || [[ "$output" == *"Hook"* ]]
}

@test "fw enforcement status: shows layer details" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' enforcement status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Git Hooks"* ]] || [[ "$output" == *"commit-msg"* ]] || [[ "$output" == *"Layer"* ]]
}

@test "fw enforcement baseline: reports missing settings" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' enforcement baseline"
    # Exits non-zero when no .claude/settings.json exists
    [[ "$output" == *"settings"* ]] || [[ "$output" == *"baseline"* ]] || [[ "$output" == *"No"* ]]
}
