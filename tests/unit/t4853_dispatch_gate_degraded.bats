#!/usr/bin/env bats
# T-4853 — check-agent-dispatch.sh had no degraded path: with python3 broken the
# payload decode printed nothing, TOOL_NAME was empty, the `!= Agent` test exited 0
# and FW_DISPATCH_LIMIT stopped applying. With python3 unusable the hook now greps
# the raw payload and blocks an Agent call with the T-4652 degraded banner.
#
# `! cmd` at statement position is inert in bats (T-4398): use `|| false`.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-agent-dispatch.sh"
    T="$(mktemp -d)"
    PROJ="$T/proj"
    mkdir -p "$PROJ/.context/working" "$T/bin" "$T/badpy"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    # TermLink present, so above the limit the gate blocks instead of allowing.
    printf '#!/bin/sh\nexit 0\n' > "$T/bin/termlink"
    chmod +x "$T/bin/termlink"
    # A python3 that cannot run at all (broken interpreter), first on PATH in the test only.
    printf '#!/bin/sh\necho "python3: broken" >&2\nexit 1\n' > "$T/badpy/python3"
    chmod +x "$T/badpy/python3"
    unset FW_DISPATCH_LIMIT
}

teardown() { rm -rf "$T"; }

gate() {  # path-prefix payload [limit]
    printf '%s' "$2" > "$T/payload.json"
    run bash -c "cd '$PROJ' && PATH='$1':\"\$PATH\" PROJECT_ROOT='$PROJ' FW_DISPATCH_LIMIT='${3:-0}' bash '$HOOK' < '$T/payload.json'"
}

@test "T-4853: broken python + Agent payload is BLOCKED with the degraded banner" {
    gate "$T/badpy:$T/bin" '{"tool_name":"Agent","session_id":"s1","tool_input":{"prompt":"x"}}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"HOOK DEGRADED"* ]]
    [[ "$output" == *"T-4652"* ]]
}

@test "T-4853: broken python + Agent payload with spaced JSON is BLOCKED" {
    gate "$T/badpy:$T/bin" '{ "tool_name" : "Agent", "session_id": "s1" }'
    [ "$status" -eq 2 ]
    [[ "$output" == *"HOOK DEGRADED"* ]]
}

@test "T-4853: broken python + Agent payload is BLOCKED even without termlink on PATH" {
    gate "$T/badpy" '{"tool_name":"Agent","session_id":"s1"}'
    [ "$status" -eq 2 ]
    [[ "$output" == *"HOOK DEGRADED"* ]]
}

@test "T-4853: broken python + non-Agent payload passes" {
    gate "$T/badpy:$T/bin" '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
    [ "$status" -eq 0 ]
}

@test "T-4853: broken python + a prompt that merely mentions Agent passes" {
    gate "$T/badpy:$T/bin" '{"tool_name":"Bash","tool_input":{"command":"echo tool_name Agent"}}'
    [ "$status" -eq 0 ]
}

@test "T-4853: healthy python + Agent within the limit is allowed, no banner" {
    gate "$T/bin" '{"tool_name":"Agent","session_id":"s1"}' 1
    [ "$status" -eq 0 ]
    [[ "$output" != *"HOOK DEGRADED"* ]] || false
}

@test "T-4853: healthy python + Agent over the limit uses the normal block, no banner" {
    gate "$T/bin" '{"tool_name":"Agent","session_id":"s1"}' 0
    [ "$status" -eq 2 ]
    [[ "$output" == *"BLOCKED: Agent dispatch #1"* ]]
    [[ "$output" != *"HOOK DEGRADED"* ]] || false
}

@test "T-4853: healthy python + non-Agent payload passes silently" {
    gate "$T/bin" '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
