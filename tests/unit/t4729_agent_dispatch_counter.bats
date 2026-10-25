#!/usr/bin/env bats
# T-4729 — check-agent-dispatch.sh counted blocked attempts and never reset per
# session (reported by 010-termlink, TermLink T-2981 2a). The counter now counts
# only allowed dispatches and is keyed to the session id.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-agent-dispatch.sh"
    T="$(mktemp -d)"
    PROJ="$T/proj"
    mkdir -p "$PROJ/.context/working" "$T/bin"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    # TermLink present, so above the limit the gate blocks instead of allowing.
    printf '#!/bin/sh\nexit 0\n' > "$T/bin/termlink"
    chmod +x "$T/bin/termlink"
    COUNTER="$PROJ/.context/working/.agent-dispatch-counter"
    unset FW_DISPATCH_LIMIT
}

teardown() { rm -rf "$T"; }

gate() {  # session-id [limit]
    run bash -c "cd '$PROJ' && PATH='$T/bin':\"\$PATH\" PROJECT_ROOT='$PROJ' FW_DISPATCH_LIMIT='${2:-0}' bash '$HOOK' <<< '{\"tool_name\":\"Agent\",\"session_id\":\"$1\"}'"
}

count() { read -r c _ < "$COUNTER"; echo "$c"; }

@test "T-4729: two blocked attempts leave the count unchanged" {
    gate sess-a
    [ "$status" -eq 2 ]
    gate sess-a
    [ "$status" -eq 2 ]
    if [ -f "$COUNTER" ]; then [ "$(count)" -eq 0 ]; fi
}

@test "T-4729: DISPATCH_LIMIT=1 allows one dispatch and blocks the second" {
    gate sess-a 1
    [ "$status" -eq 0 ]
    [ "$(count)" -eq 1 ]
    gate sess-a 1
    [ "$status" -eq 2 ]
    [[ "$output" == *"BLOCKED: Agent dispatch #2"* ]]
    [ "$(count)" -eq 1 ]
}

@test "T-4729: a new session id starts at 0" {
    gate sess-a 1
    [ "$status" -eq 0 ]
    gate sess-a 1
    [ "$status" -eq 2 ]
    gate sess-b 1
    [ "$status" -eq 0 ]
    [ "$(count)" -eq 1 ]
    grep -q "sess-b" "$COUNTER"
}

@test "T-4729: without a payload session id the framework session.yaml keys the counter" {
    printf 'session_id: S-2026-0101-0000\n' > "$PROJ/.context/working/session.yaml"
    run bash -c "cd '$PROJ' && PATH='$T/bin':\"\$PATH\" PROJECT_ROOT='$PROJ' FW_DISPATCH_LIMIT=1 bash '$HOOK' <<< '{\"tool_name\":\"Agent\"}'"
    [ "$status" -eq 0 ]
    grep -q "^1 S-2026-0101-0000$" "$COUNTER"
}

@test "T-4729: a legacy bare-number counter from another session does not carry over" {
    echo 7 > "$COUNTER"
    gate sess-a 1
    [ "$status" -eq 0 ]
    [ "$(count)" -eq 1 ]
}

@test "T-4729: fw dispatch reset still clears the counter" {
    gate sess-a 1
    [ -f "$COUNTER" ]
    run bash -c "cd '$PROJ' && PROJECT_ROOT='$PROJ' '$FRAMEWORK_ROOT/bin/fw' dispatch reset"
    [ "$status" -eq 0 ]
    [ ! -f "$COUNTER" ]
    gate sess-a 1
    [ "$status" -eq 0 ]
}

@test "T-4729: non-Agent tools are ignored and not counted" {
    run bash -c "cd '$PROJ' && PROJECT_ROOT='$PROJ' bash '$HOOK' <<< '{\"tool_name\":\"Bash\",\"session_id\":\"sess-a\"}'"
    [ "$status" -eq 0 ]
    [ ! -f "$COUNTER" ]
}
