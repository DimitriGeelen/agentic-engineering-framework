#!/usr/bin/env bats
# Unit tests for lib/update.sh
#
# Tests do_update argument parsing and help

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/compat.sh"
    source "$FRAMEWORK_ROOT/lib/update.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "update: do_update --help shows usage" {
    run do_update --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw update"* ]]
    [[ "$output" == *"--check"* ]]
    [[ "$output" == *"--branch"* ]]
    [[ "$output" == *"--rollback"* ]]
}

@test "update: do_update rejects unknown option" {
    run do_update --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "update: do_update rejects unexpected argument" {
    run do_update something
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unexpected argument"* ]]
}
