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

# T-2850: both tests below previously asserted only that the output contained a
# substring, and neither checked an exit status. The second accepted the literal
# string "status" — which is part of the command being invoked, so it matched
# even on an error path. A command that crashed while printing its own name
# passed. Exit status is now the primary assertion; the substring is secondary.

@test "fw onboarding: shows status" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' onboarding"
    [ "$status" -eq 0 ]
    [[ "$output" == *"nboarding"* ]] || [[ "$output" == *"complete"* ]] || [[ "$output" == *"pending"* ]]
}

@test "fw onboarding status: runs without error" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' onboarding status"
    [ "$status" -eq 0 ]
    # "status" dropped from the accepted set: it is the subcommand's own name and
    # so cannot distinguish a real report from an error mentioning the command.
    [[ "$output" == *"nboarding"* ]] || [[ "$output" == *"complete"* ]] || [[ "$output" == *"pending"* ]]
}
