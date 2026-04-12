#!/usr/bin/env bats
# Unit tests for agents/context/block-task-tools.sh (T-1117)
#
# PreToolUse hook that blocks TodoWrite/TaskCreate/TaskUpdate/TaskList/TaskGet.
# Exit code: always 2 (block). Redirects to bin/fw work-on.

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/block-task-tools.sh"

@test "block-task-tools: always exits 2 (block)" {
    run bash -c "echo '{}' | '$HOOK'"
    [ "$status" -eq 2 ]
}

@test "block-task-tools: output mentions BLOCKED" {
    run bash -c "echo '{}' | '$HOOK'"
    [[ "$output" == *"BLOCKED"* ]]
}

@test "block-task-tools: output mentions fw work-on" {
    run bash -c "echo '{}' | '$HOOK'"
    [[ "$output" == *"fw work-on"* ]]
}

@test "block-task-tools: output mentions ungoverned" {
    run bash -c "echo '{}' | '$HOOK'"
    [[ "$output" == *"ungoverned"* ]]
}

@test "block-task-tools: works with TodoWrite JSON payload" {
    run bash -c 'echo "{\"tool_name\":\"TodoWrite\",\"tool_input\":{\"todos\":[{\"content\":\"test\",\"status\":\"in_progress\"}]}}" | '"'$HOOK'"
    [ "$status" -eq 2 ]
}

@test "block-task-tools: works with no stdin" {
    run bash "$HOOK" < /dev/null
    [ "$status" -eq 2 ]
}

@test "block-task-tools: routable via fw hook" {
    run bash -c "echo '{}' | '$FRAMEWORK_ROOT/bin/fw' hook block-task-tools"
    [ "$status" -eq 2 ]
    [[ "$output" == *"BLOCKED"* ]]
}
