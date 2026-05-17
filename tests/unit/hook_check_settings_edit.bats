#!/usr/bin/env bats
# T-1888: PostToolUse hook check-settings-edit.sh — fires advisory L-398 reminder
# when .claude/settings.json is written/edited. Strictly advisory (exit 0).
#
# Pattern matches existing check-fabric-new-file.sh tests: stdin JSON, stdout
# either empty (no match) or a JSON envelope with additionalContext.

load ../test_helper

run_hook() {
    local payload="$1"
    local hook="$FRAMEWORK_ROOT/agents/context/check-settings-edit.sh"
    run bash -c "echo '$payload' | bash '$hook'"
}

@test "T-1888: Edit on .claude/settings.json fires L-398 reminder" {
    run_hook '{"tool_name":"Edit","tool_input":{"file_path":".claude/settings.json"}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"L-398"* ]]
    [[ "$output" == *"enforcement baseline"* ]]
    [[ "$output" == *"additionalContext"* ]]
}

@test "T-1888: Write on .claude/settings.json fires L-398 reminder (absolute path)" {
    run_hook '{"tool_name":"Write","tool_input":{"file_path":"/repo/.claude/settings.json"}}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"L-398"* ]]
}

@test "T-1888: Edit on unrelated file is silent" {
    run_hook '{"tool_name":"Edit","tool_input":{"file_path":"random/file.py"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-1888: Bash tool is silent (defence in depth)" {
    run_hook '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-1888: malformed JSON tolerated — no crash, no output" {
    local hook="$FRAMEWORK_ROOT/agents/context/check-settings-edit.sh"
    run bash -c "echo 'not json' | bash '$hook'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-1888: Edit on settings.json look-alike in wrong dir is silent" {
    run_hook '{"tool_name":"Edit","tool_input":{"file_path":"other/settings.json"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
