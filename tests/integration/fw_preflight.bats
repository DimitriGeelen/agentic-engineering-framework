#!/usr/bin/env bats
# Integration tests for fw preflight subcommand

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

@test "fw preflight: runs dependency check" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' preflight"
    [ "$status" -eq 0 ]
    [[ "$output" == *"bash"* ]] || [[ "$output" == *"git"* ]] || [[ "$output" == *"python"* ]]
}

@test "fw preflight: shows OK for required deps" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' preflight"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}
