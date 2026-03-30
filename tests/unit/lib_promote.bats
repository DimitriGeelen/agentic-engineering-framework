#!/usr/bin/env bats
# Unit tests for lib/promote.sh
#
# Tests do_promote routing, help, and error handling

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/promote.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "promote: do_promote --help shows usage" {
    run do_promote --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw promote"* ]]
    [[ "$output" == *"suggest"* ]]
    [[ "$output" == *"status"* ]]
}

@test "promote: do_promote with no args shows help" {
    run do_promote ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw promote"* ]]
}

@test "promote: do_promote --help shows examples" {
    run do_promote --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Examples"* ]]
    [[ "$output" == *"L-008"* ]]
}

@test "promote: do_promote rejects unknown subcommand" {
    run do_promote bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown promote subcommand"* ]]
}

@test "promote: do_promote suggest requires learnings file" {
    # No learnings.yaml exists — Python should fail
    run do_promote suggest
    [ "$status" -ne 0 ]
    [[ "$output" == *"No learnings file"* ]]
}

@test "promote: do_promote status requires learnings file" {
    run do_promote status
    [ "$status" -ne 0 ]
    [[ "$output" == *"No learnings file"* ]]
}

@test "promote: do_promote suggest with empty learnings" {
    mkdir -p "$TEST_TEMP_DIR/.context/project"
    echo "learnings: []" > "$TEST_TEMP_DIR/.context/project/learnings.yaml"
    run do_promote suggest
    [ "$status" -eq 0 ]
}

@test "promote: do_promote status with empty learnings" {
    mkdir -p "$TEST_TEMP_DIR/.context/project"
    echo "learnings: []" > "$TEST_TEMP_DIR/.context/project/learnings.yaml"
    run do_promote status
    [ "$status" -eq 0 ]
}
