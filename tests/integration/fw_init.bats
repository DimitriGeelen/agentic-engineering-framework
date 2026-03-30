#!/usr/bin/env bats
# Integration tests for fw init subcommand
#
# Tests framework initialization in a fresh directory.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Init ---

@test "fw init: creates .framework.yaml in target dir" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' init '$PROJECT_ROOT'"
    [ "$status" -eq 0 ]
    [ -f "$PROJECT_ROOT/.framework.yaml" ]
}

@test "fw init: creates task directories" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' init '$PROJECT_ROOT'" > /dev/null 2>&1
    [ -d "$PROJECT_ROOT/.tasks/active" ]
    [ -d "$PROJECT_ROOT/.tasks/completed" ]
}

@test "fw init: creates context directories" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' init '$PROJECT_ROOT'" > /dev/null 2>&1
    [ -d "$PROJECT_ROOT/.context/working" ]
    [ -d "$PROJECT_ROOT/.context/project" ]
}
