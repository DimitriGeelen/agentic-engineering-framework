#!/usr/bin/env bats
# T-3989 (1409, urgent): sessions were cut off at the hard budget block instead of handing
# over. (2) The critical auto-handover lived only in PostToolUse checkpoint.sh, and
# PostToolUse never runs on a call PreToolUse budget-gate BLOCKED — so it never ran.
# (5) A non-integer cache age broke every [ -lt ] in the fast path ("integer expression
# expected", 74x in one 1409 session).

load ../test_helper

BUDGET_GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
CHECKPOINT="$FRAMEWORK_ROOT/agents/context/checkpoint.sh"
ME="33333333-cccc-4ccc-8ccc-000000000003"

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working" "$TEST_TEMP_DIR/home"
    echo "session_id: S-TEST-3989" > "$PROJ/.context/working/session.yaml"
    BIG="$TEST_TEMP_DIR/$ME-big.jsonl"
    line='{"message":{"model":"claude-opus-5","usage":{"input_tokens":295000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
    printf '%s\n%s\n' "$line" "$line" > "$BIG"
    CALLS="$TEST_TEMP_DIR/checkpoint-calls"
    STUB="$TEST_TEMP_DIR/checkpoint-stub.sh"
    printf '#!/bin/bash\necho "$*" >> %q\n' "$CALLS" > "$STUB"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_gate() {   # $1 = command for the Bash tool call
    echo 2 > "$PROJ/.context/working/.budget-gate-counter"
    # A foreign-session cache forces the slow path (re-read of THIS transcript), as in
    # t3598 — with no cache at all the gate skips the check on that call.
    [ -f "$PROJ/.context/working/.budget-status" ] || printf '{"level": "ok", "tokens": 0, "timestamp": %d, "session_id": "S-TEST-3989", "claude_session_id": "other", "source": "budget-gate"}' "$(date +%s)" > "$PROJ/.context/working/.budget-status"
    local input="{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$ME\",\"transcript_path\":\"$BIG\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}"
    run bash -c "printf '%s' '$input' | PROJECT_ROOT='$PROJ' CONTEXT_DIR='$PROJ/.context' HOME='$TEST_TEMP_DIR/home' FW_CONTEXT_WINDOW=300000 FW_CHECKPOINT_SH='$STUB' bash '$BUDGET_GATE'"
}

_wait_calls() { local i; for i in 1 2 3 4 5 6 7 8 9 10; do [ -s "$CALLS" ] && return 0; sleep 0.2; done; return 1; }

@test "T-3989 (2): a call BLOCKED at critical starts the auto-handover itself" {
    _gate "make build"
    [ "$status" -eq 2 ]
    [[ "$output" == *"AUTO-HANDOVER: started in the background"* ]]
    _wait_calls
    grep -q "^auto-handover 295000" "$CALLS"
}

@test "T-3989 (2)/control: an ALLOWED wrap-up call at critical does not start one" {
    _gate "git commit -m wip"
    [ "$status" -eq 0 ]
    sleep 1
    [ ! -s "$CALLS" ]
}

@test "T-3989 (2): checkpoint.sh has the auto-handover subcommand and post-tool uses the same function" {
    grep -q '^    auto-handover)' "$CHECKPOINT"
    [ "$(grep -c '_auto_handover_at_critical "' "$CHECKPOINT")" -ge 2 ]
}

@test "T-3989 (5): a non-numeric cache age never reaches a [ -lt ] test" {
    printf '{"level": "ok", "tokens": 1000, "timestamp": "7 | sys.path.insert(0,x)", "session_id": "S-TEST-3989", "claude_session_id": "%s", "source": "budget-gate"}' \
        "$ME" > "$PROJ/.context/working/.budget-status"
    _gate "git status"
    [[ "$output" != *"integer expression expected"* ]]
}

@test "T-3997 (1409 root cause): a multi-line refused command cannot split the result into a bad STATUS_AGE" {
    # 1409 logged "[: 42\nimport: integer expression expected": the reason field carried the
    # command's own newlines and awk printed field 3 of every line.
    _gate 'python3 -c \"\nimport sys\nsys.path.insert(0,1)\"'
    [[ "$output" != *"integer expression expected"* ]]
    [[ "$output" != *"ignoring non-numeric cache age"* ]]
}
