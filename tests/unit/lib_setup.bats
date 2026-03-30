#!/usr/bin/env bats
# Unit tests for lib/setup.sh
#
# Tests do_setup argument parsing and help

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/setup.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "setup: do_setup --help shows usage" {
    run do_setup --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw setup"* ]]
    [[ "$output" == *"Project Identity"* ]]
    [[ "$output" == *"Provider Selection"* ]]
    [[ "$output" == *"--non-interactive"* ]]
}

@test "setup: do_setup rejects unknown option" {
    run do_setup --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}
