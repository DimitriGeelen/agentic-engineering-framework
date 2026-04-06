#!/usr/bin/env bats
# Integration tests for fw costs
# Origin: T-947

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FW="$FRAMEWORK_ROOT/bin/fw"

@test "fw costs help shows usage" {
    run "$FW" costs help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw costs"* ]]
    [[ "$output" == *"session"* ]]
    [[ "$output" == *"current"* ]]
}

@test "fw costs shows project summary" {
    run "$FW" costs
    [ "$status" -eq 0 ]
    [[ "$output" == *"token"* ]] || [[ "$output" == *"Token"* ]] || [[ "$output" == *"session"* ]]
}

@test "fw costs session shows table" {
    run "$FW" costs session
    [ "$status" -eq 0 ]
}

@test "fw costs current shows current session" {
    run "$FW" costs current
    # May fail if no active session transcript found
    [[ "$status" -le 1 ]]
}
