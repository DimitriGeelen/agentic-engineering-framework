#!/usr/bin/env bats
# Integration tests for fw self-test
# Origin: T-947

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FW="$FRAMEWORK_ROOT/bin/fw"

@test "fw self-test runs gate tests" {
    run "$FW" self-test
    [ "$status" -le 1 ]  # May have failures but should complete
    [[ "$output" == *"gate"* ]] || [[ "$output" == *"self-test"* ]]
}

@test "fw self-test runs lifecycle tests" {
    run "$FW" self-test
    [[ "$output" == *"lifecycle"* ]]
}

@test "fw self-test runs onboarding tests" {
    run "$FW" self-test
    [[ "$output" == *"onboarding"* ]]
}

@test "fw self-test shows pass/fail results" {
    run "$FW" self-test
    [[ "$output" == *"PASS"* ]] || [[ "$output" == *"pass"* ]]
}
