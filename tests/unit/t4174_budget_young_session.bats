#!/usr/bin/env bats
# T-4174 (dimitri-mint-dev P-012) — in the session a budget restart starts, the
# gauge read {"level":"unknown","note":"scan failed or produced no data"}: the
# first PreToolUse call runs after ONE assistant response, so the transcript
# holds a single usage entry, and lib/context_tokens.py's "< 2 in-scope entries,
# do not guess" branch returned the same empty model as a crashed scan. The gate
# could not tell a young session from a failed one.
#
# Fix: context_tokens.py --with-status names the state (measured/young/empty)
# and carries the lone reading; the gate reports a young session below the warn
# line as ok + real tokens + "provisional": true, and keeps "unknown" for an
# empty/unparseable transcript and for a lone reading at/above warn (the T-2885
# foreign cache-priming shape).

load ../test_helper

BUDGET_GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
MODULE="$FRAMEWORK_ROOT/lib/context_tokens.py"

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Same harness shape as t3241: fresh PROJECT_ROOT per call so the slow path runs.
run_gate() {
    local label="$1" transcript="$2"
    local proj="$TEST_TEMP_DIR/$label"
    mkdir -p "$proj/.context/working"
    echo "0" > "$proj/.context/working/.budget-gate-counter"
    echo "session_id: S-TEST-4174" > "$proj/.context/working/session.yaml"
    local home="$TEST_TEMP_DIR/home-$label"
    mkdir -p "$home"
    local input="{\"hook_event_name\":\"PreToolUse\",\"transcript_path\":\"$transcript\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\"}}"
    run bash -c "printf '%s' '$input' | PROJECT_ROOT='$proj' CONTEXT_DIR='$proj/.context' HOME='$home' FW_CONTEXT_WINDOW=300000 bash '$BUDGET_GATE'"
    STATUS_JSON="$(cat "$proj/.context/working/.budget-status" 2>/dev/null || echo '{}')"
}

# The fresh-after-restart shape: injected handover/user turn + one tool_use response.
_young_transcript() {
    local f="$1" tokens="$2"
    printf '%s\n' \
        '{"type":"user","message":{"role":"user","content":"resume from handover"}}' \
        "{\"type\":\"assistant\",\"message\":{\"model\":\"claude-opus-5\",\"usage\":{\"input_tokens\":${tokens},\"cache_read_input_tokens\":0,\"cache_creation_input_tokens\":0}}}" \
        > "$f"
}

@test "young session: first call after a restart reports ok + the real low reading, not 'scan failed'" {
    f="$TEST_TEMP_DIR/young.jsonl"
    _young_transcript "$f" 30000
    run_gate young "$f"
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"level": "ok"'
    echo "$STATUS_JSON" | grep -q '"tokens": 30000'
    echo "$STATUS_JSON" | grep -q '"provisional": true'
    ! echo "$STATUS_JSON" | grep -q 'scan failed' || false
}

@test "young session with no usage entry yet reports ok/0 provisional (transcript parses)" {
    f="$TEST_TEMP_DIR/no-usage.jsonl"
    printf '%s\n' '{"type":"user","message":{"role":"user","content":"hi"}}' > "$f"
    run_gate nousage "$f"
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"level": "ok"'
    echo "$STATUS_JSON" | grep -q '"tokens": 0'
    echo "$STATUS_JSON" | grep -q '"provisional": true'
}

@test "lone HIGH reading (T-2885 poisoning shape) is still unknown, never trusted" {
    f="$TEST_TEMP_DIR/lone-high.jsonl"
    _young_transcript "$f" 280000
    run_gate lonehigh "$f"
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"level": "unknown"'
    echo "$STATUS_JSON" | grep -q '"tokens": null'
}

@test "empty transcript (nothing parses) is still unknown" {
    f="$TEST_TEMP_DIR/empty.jsonl"
    : > "$f"
    run_gate empty "$f"
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"level": "unknown"'
}

@test "confirmed measurement carries no provisional marker" {
    f="$TEST_TEMP_DIR/measured.jsonl"
    _young_transcript "$f" 30000
    printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-5","usage":{"input_tokens":32000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}' >> "$f"
    run_gate measured "$f"
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"tokens": 32000'
    ! echo "$STATUS_JSON" | grep -q 'provisional' || false
}

@test "context_tokens.py --with-status names the state; default output unchanged" {
    f="$TEST_TEMP_DIR/mod.jsonl"
    _young_transcript "$f" 30000
    run bash -c "python3 '$MODULE' '' --with-status < '$f'"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '0\t\tyoung\t30000')" ]
    run bash -c "python3 '$MODULE' '' < '$f'"
    [ "$output" = "0" ]
    run bash -c "python3 '$MODULE' '' --with-status < /dev/null"
    [ "$output" = "$(printf '0\t\tempty\t0')" ]
}
