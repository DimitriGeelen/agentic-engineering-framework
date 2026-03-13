#!/usr/bin/env bats
# Integration tests for agents/context/block-plan-mode.sh
#
# This script is a PreToolUse hook that unconditionally blocks EnterPlanMode.
# Exit code: always 2 (block)

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/block-plan-mode.sh"

@test "block: EnterPlanMode is always blocked with exit 2" {
    run bash -c "echo '{}' | '$HOOK'"
    [ "$status" -eq 2 ]
}

@test "block: output mentions /plan as alternative" {
    run bash -c "echo '{}' | '$HOOK'"
    [[ "$output" == *"/plan"* ]]
}

@test "block: output mentions BLOCKED" {
    run bash -c "echo '{}' | '$HOOK'"
    [[ "$output" == *"BLOCKED"* ]]
}

@test "block: output mentions governance bypass" {
    run bash -c "echo '{}' | '$HOOK'"
    [[ "$output" == *"governance"* ]]
}
