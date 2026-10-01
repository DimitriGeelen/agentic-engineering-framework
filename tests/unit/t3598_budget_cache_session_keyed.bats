#!/usr/bin/env bats
# T-3598 — .budget-status is one project-wide cache written by EVERY Claude
# process in the project (the parent session and every TermLink worker). The
# gate's fast path trusted any cache under STATUS_MAX_AGE by age alone, so:
#   (a) a parent at `critical` blocked every worker's Bash call, and
#   (b) a worker's low reading was served as the parent's budget (false tokens:0).
# The framework `session_id` the cache already carried (T-3241) comes from
# session.yaml, which every Claude process in the project shares, so it could
# never tell two Claude sessions apart. The fix stamps the CLAUDE session id
# (hook stdin `session_id`; `CLAUDE_CODE_SESSION_ID` in a Bash call) as
# `claude_session_id` and trusts the cache only when it matches the caller.
#
# Fixtures only: tmp PROJECT_ROOT, synthetic transcripts, synthetic caches.

load ../test_helper

BUDGET_GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
CHECKPOINT="$FRAMEWORK_ROOT/agents/context/checkpoint.sh"

ME="11111111-aaaa-4aaa-8aaa-000000000001"
OTHER="22222222-bbbb-4bbb-8bbb-000000000002"

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working" "$TEST_TEMP_DIR/home"
    # Both Claude processes share ONE framework session — the real topology.
    echo "session_id: S-TEST-0001" > "$PROJ/.context/working/session.yaml"
    SMALL="$TEST_TEMP_DIR/$ME-small.jsonl"
    BIG="$TEST_TEMP_DIR/$ME-big.jsonl"
    _transcript "$SMALL" 20000
    _transcript "$BIG" 295000
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# _transcript FILE TOKENS — two same-model usage entries (the scan needs >= 2).
_transcript() {
    local f="$1" t="$2" line
    line="{\"message\":{\"model\":\"claude-opus-5\",\"usage\":{\"input_tokens\":$t,\"cache_read_input_tokens\":0,\"cache_creation_input_tokens\":0}}}"
    printf '%s\n%s\n' "$line" "$line" > "$f"
}

# _cache LEVEL TOKENS CLAUDE_SID — fresh cache written by the given Claude session.
_cache() {
    printf '{"level": "%s", "tokens": %s, "timestamp": %d, "session_id": "S-TEST-0001", "claude_session_id": "%s", "source": "budget-gate"}' \
        "$1" "$2" "$(date +%s)" "$3" > "$PROJ/.context/working/.budget-status"
}

# _gate TRANSCRIPT [COUNTER] — a Bash call from session $ME. COUNTER defaults to
# 2, so an UNFORCED slow path would skip (2 % 5 != 1): only the fast path or a
# forced re-read can decide.
_gate() {
    echo "${2:-2}" > "$PROJ/.context/working/.budget-gate-counter"
    local input="{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$ME\",\"transcript_path\":\"$1\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"make build\"}}"
    run bash -c "printf '%s' '$input' | PROJECT_ROOT='$PROJ' CONTEXT_DIR='$PROJ/.context' HOME='$TEST_TEMP_DIR/home' FW_CONTEXT_WINDOW=300000 bash '$BUDGET_GATE'"
}

_budget() {
    run bash -c "PROJECT_ROOT='$PROJ' CONTEXT_DIR='$PROJ/.context' HOME='$TEST_TEMP_DIR/home' CLAUDE_CODE_SESSION_ID='$1' bash '$CHECKPOINT' budget"
}

# --- Symptom (a): a foreign critical cache blocks a healthy session ---------

@test "(a) foreign-session critical cache does not block a Bash call from a session whose own transcript is small" {
    _cache critical 290000 "$OTHER"
    _gate "$SMALL"
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q "SESSION WRAPPING UP"
}

@test "(a) the forced re-read replaces the foreign cache with the caller's own reading, stamped with its identity" {
    _cache critical 290000 "$OTHER"
    _gate "$SMALL"
    grep -q "\"claude_session_id\": \"$ME\"" "$PROJ/.context/working/.budget-status"
    grep -q '"tokens": 20000' "$PROJ/.context/working/.budget-status"
}

@test "(a, other direction) foreign-session ok cache does not let a critical session through" {
    _cache ok 0 "$OTHER"
    _gate "$BIG"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "SESSION WRAPPING UP"
}

# --- Symptom (b): a foreign ok/0 reported as the caller's budget -------------

@test "(b) checkpoint.sh budget does not report a foreign session's ok/tokens:0 as the caller's budget" {
    _cache ok 0 "$OTHER"
    _budget "$ME"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^level: unknown'
    echo "$output" | grep -q "written by Claude session $OTHER"
    ! echo "$output" | grep -q '^tokens: 0'
}

# --- Controls: same-session caches keep the fast path ------------------------

@test "control: same-session critical cache still blocks (fast path, small transcript never read)" {
    _cache critical 290000 "$ME"
    _gate "$SMALL"
    [ "$status" -eq 2 ]
    echo "$output" | grep -q "SESSION WRAPPING UP"
}

@test "control: same-session ok cache still takes the fast path (a critical transcript is not re-read)" {
    _cache ok 20000 "$ME"
    _gate "$BIG"
    [ "$status" -eq 0 ]
    # The fast path does not rewrite the cache.
    grep -q '"tokens": 20000' "$PROJ/.context/working/.budget-status"
}

@test "control: checkpoint.sh budget reports a same-session cache as the caller's budget" {
    _cache ok 20000 "$ME"
    _budget "$ME"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^level: ok'
    echo "$output" | grep -q '^tokens: 20000'
}

@test "control: a legacy cache with no claude_session_id keeps the old fast-path behaviour" {
    printf '{"level": "critical", "tokens": 290000, "timestamp": %d, "source": "budget-gate"}' "$(date +%s)" \
        > "$PROJ/.context/working/.budget-status"
    _gate "$SMALL"
    [ "$status" -eq 2 ]
}
