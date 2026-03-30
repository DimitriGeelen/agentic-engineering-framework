#!/usr/bin/env bats
# Unit tests for lib/dispatch.sh
#
# Tests do_dispatch routing, help, send validation

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/dispatch.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "dispatch: do_dispatch_help shows usage" {
    run do_dispatch_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw dispatch"* ]]
    [[ "$output" == *"send"* ]]
    [[ "$output" == *"hosts"* ]]
}

@test "dispatch: do_dispatch routes help" {
    run do_dispatch --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw dispatch"* ]]
}

@test "dispatch: do_dispatch routes empty to help" {
    run do_dispatch
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw dispatch"* ]]
}

@test "dispatch: do_dispatch rejects unknown subcommand" {
    run do_dispatch bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown dispatch command"* ]]
}

@test "dispatch: do_dispatch_send requires --host" {
    run do_dispatch_send --task T-999 --agent explore --summary "test"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--host is required"* ]]
}

@test "dispatch: do_dispatch_send requires --task" {
    run do_dispatch_send --host remote --agent explore --summary "test"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--task is required"* ]]
}

@test "dispatch: do_dispatch_send requires --agent" {
    run do_dispatch_send --host remote --task T-999 --summary "test"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--agent is required"* ]]
}

@test "dispatch: do_dispatch_send requires --summary" {
    run do_dispatch_send --host remote --task T-999 --agent explore
    [ "$status" -eq 1 ]
    [[ "$output" == *"--summary is required"* ]]
}

@test "dispatch: do_dispatch_send --help exits 0" {
    run do_dispatch_send --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw dispatch"* ]]
}
