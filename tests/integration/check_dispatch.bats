#!/usr/bin/env bats
# Integration tests for agents/context/check-dispatch.sh
#
# PostToolUse hook that warns when sub-agent results exceed size thresholds.
# Exit code: always 0 (advisory only)
# Output: JSON additionalContext when oversized

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/check-dispatch.sh"

# Helper: create a JSON payload simulating a Task tool response
make_payload() {
    local tool_name="$1"
    local content_size="${2:-100}"
    # Generate content of approximate size
    local content
    content=$(python3 -c "print('x' * $content_size)")
    echo "{\"tool_name\": \"$tool_name\", \"tool_response\": \"$content\"}"
}

@test "silent: non-Task tool is ignored" {
    local json='{"tool_name": "Write", "tool_response": "some output"}'
    run bash -c "echo '$json' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent: Task with small response (<5K) is allowed" {
    local json
    json=$(make_payload "Task" 100)
    run bash -c "echo '$json' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "warn: Task with response >5K chars triggers WARNING" {
    local json
    json=$(make_payload "Task" 6000)
    run bash -c "echo '$json' | '$HOOK'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [[ "$output" == *"DISPATCH GUARD"* ]]
}

@test "critical: Task with response >20K chars triggers CRITICAL" {
    local json
    json=$(make_payload "Task" 25000)
    run bash -c "echo '$json' | '$HOOK'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CRITICAL"* ]]
    [[ "$output" == *"CONTEXT FLOOD"* ]]
}

@test "warn: TaskOutput with large response also triggers" {
    local json
    json=$(make_payload "TaskOutput" 6000)
    run bash -c "echo '$json' | '$HOOK'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISPATCH GUARD"* ]]
}

@test "silent: empty tool_response is ignored" {
    local json='{"tool_name": "Task", "tool_response": ""}'
    run bash -c "echo '$json' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "output: warning mentions preamble.md" {
    local json
    json=$(make_payload "Task" 6000)
    run bash -c "echo '$json' | '$HOOK'"
    [[ "$output" == *"preamble.md"* ]]
}

@test "resilient: malformed JSON input exits 0" {
    run bash -c "echo 'not json' | '$HOOK'"
    [ "$status" -eq 0 ]
}
