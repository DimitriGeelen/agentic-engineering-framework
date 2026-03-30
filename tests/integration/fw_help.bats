#!/usr/bin/env bats
# Integration tests for fw help subcommand

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

# --- Help ---

@test "fw help: shows usage" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]] || [[ "$output" == *"Commands:"* ]]
}

@test "fw help: lists common commands" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"audit"* ]]
    [[ "$output" == *"task"* ]]
    [[ "$output" == *"context"* ]]
}
