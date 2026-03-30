#!/usr/bin/env bats
# Unit tests for lib/assumption.sh
#
# Tests do_assumption routing, help, validation, ensure_assumptions_file

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/assumption.sh"

    mkdir -p "$TEST_TEMP_DIR/.context/project"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "assumption: show_assumption_help shows commands" {
    run show_assumption_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw assumption"* ]]
    [[ "$output" == *"add"* ]]
    [[ "$output" == *"validate"* ]]
    [[ "$output" == *"invalidate"* ]]
    [[ "$output" == *"list"* ]]
}

@test "assumption: do_assumption routes help" {
    run do_assumption --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw assumption"* ]]
}

@test "assumption: do_assumption routes empty to help" {
    run do_assumption ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw assumption"* ]]
}

@test "assumption: do_assumption rejects unknown subcommand" {
    run do_assumption bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown assumption subcommand"* ]]
}

@test "assumption: do_assumption_add requires statement" {
    run do_assumption_add ""
    [ "$status" -eq 1 ]
}

@test "assumption: do_assumption_add requires task" {
    run do_assumption_add "Users want notifications"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Task ID required"* ]]
}

@test "assumption: ensure_assumptions_file creates file" {
    rm -f "$ASSUMPTIONS_FILE"
    ensure_assumptions_file
    [ -f "$ASSUMPTIONS_FILE" ]
    grep -q "assumptions:" "$ASSUMPTIONS_FILE"
}

@test "assumption: ensure_assumptions_file is idempotent" {
    ensure_assumptions_file
    local before
    before=$(cat "$ASSUMPTIONS_FILE")
    ensure_assumptions_file
    local after
    after=$(cat "$ASSUMPTIONS_FILE")
    [ "$before" = "$after" ]
}

@test "assumption: do_assumption_add creates assumption" {
    run do_assumption_add "Users want X" --task T-999
    [ "$status" -eq 0 ]
    [[ "$output" == *"A-"* ]]
    grep -q "Users want X" "$ASSUMPTIONS_FILE"
}

@test "assumption: do_assumption_list runs without error" {
    ensure_assumptions_file
    run do_assumption list
    [ "$status" -eq 0 ]
}

@test "assumption: do_assumption_list shows added assumption" {
    do_assumption_add "Test assumption" --task T-999
    run do_assumption list
    [ "$status" -eq 0 ]
    [[ "$output" == *"Test assumption"* ]]
}
