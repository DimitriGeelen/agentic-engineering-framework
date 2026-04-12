#!/usr/bin/env bats
# Unit tests for agents/context/audit-task-tools.sh (T-1118)
#
# PostToolUse scanner that detects TodoWrite/TaskCreate usage and warns.
# Exit code: always 0 (advisory). Output: JSON additionalContext when banned tool found.

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/audit-task-tools.sh"

@test "audit-task-tools: always exits 0" {
    run bash -c 'echo "{\"tool_name\":\"TodoWrite\"}" | '"'$HOOK'"
    [ "$status" -eq 0 ]
}

@test "audit-task-tools: detects TodoWrite and outputs additionalContext" {
    output=$(echo '{"tool_name":"TodoWrite"}' | bash "$HOOK")
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'additionalContext' in d"
}

@test "audit-task-tools: detects TaskCreate and outputs additionalContext" {
    output=$(echo '{"tool_name":"TaskCreate"}' | bash "$HOOK")
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'additionalContext' in d"
}

@test "audit-task-tools: detects TaskUpdate" {
    output=$(echo '{"tool_name":"TaskUpdate"}' | bash "$HOOK")
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'additionalContext' in d"
}

@test "audit-task-tools: ignores Bash tool (no output)" {
    output=$(echo '{"tool_name":"Bash"}' | bash "$HOOK")
    [ -z "$output" ]
}

@test "audit-task-tools: ignores Write tool (no output)" {
    output=$(echo '{"tool_name":"Write"}' | bash "$HOOK")
    [ -z "$output" ]
}

@test "audit-task-tools: handles malformed JSON gracefully" {
    run bash -c 'echo "not json" | '"'$HOOK'"
    [ "$status" -eq 0 ]
}

@test "audit-task-tools: handles empty stdin" {
    run bash "$HOOK" < /dev/null
    [ "$status" -eq 0 ]
}

@test "audit-task-tools: warning mentions fw work-on" {
    output=$(echo '{"tool_name":"TodoWrite"}' | bash "$HOOK")
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'fw work-on' in d['additionalContext']"
}

@test "audit-task-tools: routable via fw hook" {
    output=$(echo '{"tool_name":"TaskCreate"}' | "$FRAMEWORK_ROOT/bin/fw" hook audit-task-tools)
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'additionalContext' in d"
}
