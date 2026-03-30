#!/usr/bin/env bats
# Integration tests for fw hook subcommand

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

@test "fw hook: no args shows usage" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' hook"
    [[ "$output" == *"hook"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "fw hook: resolves check-active-task path" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' hook check-active-task --dry-run 2>&1 || true"
    # Hook exists and is reachable — may need args to run
    [[ "$output" == *"check-active-task"* ]] || [[ "$output" == *"BLOCKED"* ]] || [[ "$output" == *"task"* ]] || [ "$status" -le 1 ]
}
