#!/usr/bin/env bats
# T-1945 — PreToolUse heredoc-in-cmd-sub guard hook tests.
#
# The hook surfaces L-332/L-408 at edit time when the agent proposes
# adding a `$(... <<TAG ... TAG)` block to bin/fw — closing the
# task-create → edit-time prevention gap that bit T-1942 twice.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-heredoc-cmd-sub.sh"
    [ -x "$HOOK" ] || skip "hook not executable: $HOOK"
}

@test "T-1945: bin/fw edit with python3 heredoc-in-cmd-sub → stderr warns about L-332/L-408" {
    payload='{"tool_name":"Edit","tool_input":{"file_path":"/repo/bin/fw","new_string":"x=$(python3 - <<PY\nprint(1)\nPY\n)"}}'
    run bash -c "echo '$payload' | bash '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "L-332"
    echo "$output" | grep -q "L-408"
}

@test "T-1945: bin/fw edit WITHOUT heredoc → hook is silent (exit 0, no stderr noise)" {
    payload='{"tool_name":"Edit","tool_input":{"file_path":"/repo/bin/fw","new_string":"plain shell code with no heredoc"}}'
    run bash -c "echo '$payload' | bash '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-1945: heredoc edit on a non-bin/fw path → out of scope, silent" {
    payload='{"tool_name":"Edit","tool_input":{"file_path":"/repo/lib/other.sh","new_string":"x=$(python3 - <<PY\nprint(1)\nPY\n)"}}'
    run bash -c "echo '$payload' | bash '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-1945: Write tool on bin/fw with heredoc in content → warns" {
    payload='{"tool_name":"Write","tool_input":{"file_path":"/repo/bin/fw","content":"#!/bin/bash\nx=$(python3 - <<PY\nprint(1)\nPY\n)"}}'
    run bash -c "echo '$payload' | bash '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "L-332"
}

@test "T-1945: non-Write/Edit tool (e.g. Bash) → silent regardless of payload" {
    payload='{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'
    run bash -c "echo '$payload' | bash '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-1945: any heredoc-in-cmd-sub (not just python3) on bin/fw → warns" {
    payload='{"tool_name":"Edit","tool_input":{"file_path":"/repo/bin/fw","new_string":"x=$(cat <<END\nhi\nEND\n)"}}'
    run bash -c "echo '$payload' | bash '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "L-332"
}

@test "T-1945: malformed JSON input → hook fails open (exit 0, silent)" {
    payload='not-valid-json'
    run bash -c "echo '$payload' | bash '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
