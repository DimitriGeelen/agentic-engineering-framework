#!/usr/bin/env bats
# Integration tests for fw version subcommand

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

# --- Version ---

@test "fw version: shows version string" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' version"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw v"* ]]
}

@test "fw version: shows framework path" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' version"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Framework:"* ]]
}
