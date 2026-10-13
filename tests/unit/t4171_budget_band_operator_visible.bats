#!/usr/bin/env bats
# T-4171 (dimitri-mint-dev P-009, their T-106) — budget warn (75%) and urgent (85%)
# never reached the operator. budget-gate.sh reported both bands as stderr on a
# PreToolUse exit 0, which Claude Code shows to neither the model nor the user, so
# the first signal anyone saw was the hard cut at 95%. The fix: on the first call of
# a Claude session in each band, emit hook JSON on stdout — `systemMessage` for the
# operator, `hookSpecificOutput.additionalContext` for the agent — and at urgent one
# fw_notify push. Fixtures only: tmp PROJECT_ROOT, synthetic transcript/cache.

load ../test_helper

BUDGET_GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
ME="11111111-aaaa-4aaa-8aaa-000000000001"
OTHER="22222222-bbbb-4bbb-8bbb-000000000002"

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working" "$TEST_TEMP_DIR/home"
    echo "session_id: S-TEST-0001" > "$PROJ/.context/working/session.yaml"
    # Fake ntfy dispatcher: records its argv, prints to stdout (which must NOT leak
    # into the hook's stdout JSON).
    DISPATCH_LOG="$TEST_TEMP_DIR/dispatch.log"
    FAKE_DISPATCHER="$TEST_TEMP_DIR/dispatcher.py"
    printf 'import sys\nopen("%s","a").write(" ".join(sys.argv[1:])+"\\n")\nprint("dispatcher noise")\n' \
        "$DISPATCH_LOG" > "$FAKE_DISPATCHER"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_transcript() {
    local f="$1" t="$2" line
    line="{\"message\":{\"model\":\"claude-opus-5\",\"usage\":{\"input_tokens\":$t,\"cache_read_input_tokens\":0,\"cache_creation_input_tokens\":0}}}"
    printf '%s\n%s\n' "$line" "$line" > "$f"
}

_cache() {
    printf '{"level": "%s", "tokens": %s, "timestamp": %d, "session_id": "S-TEST-0001", "claude_session_id": "%s", "source": "budget-gate"}' \
        "$1" "$2" "$(date +%s)" "$3" > "$PROJ/.context/working/.budget-status"
}

# _gate SID [TRANSCRIPT] [COUNTER] — one Bash call; stdout and stderr captured separately.
_gate() {
    local sid="$1" tr="${2:-/nonexistent}"
    echo "${3:-2}" > "$PROJ/.context/working/.budget-gate-counter"
    local input="{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$sid\",\"transcript_path\":\"$tr\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"make build\"}}"
    printf '%s' "$input" | PROJECT_ROOT="$PROJ" CONTEXT_DIR="$PROJ/.context" HOME="$TEST_TEMP_DIR/home" \
        FW_CONTEXT_WINDOW=300000 NTFY_ENABLED=true SKILLS_DISPATCHER="$FAKE_DISPATCHER" \
        bash "$BUDGET_GATE" > "$TEST_TEMP_DIR/out" 2> "$TEST_TEMP_DIR/err" && rc=0 || rc=$?
    echo "$rc" > "$TEST_TEMP_DIR/rc"
}

_json() {  # _json EXPR — evaluate a python expression over the hook's stdout JSON as d
    python3 -c "import json,sys; d=json.load(open('$TEST_TEMP_DIR/out')); print($1)"
}

@test "urgent (fast path): first call emits operator systemMessage + agent additionalContext, exit 0" {
    _cache urgent 260000 "$ME"
    _gate "$ME"
    [ "$(cat "$TEST_TEMP_DIR/rc")" -eq 0 ]
    _json "d['systemMessage']" | grep -qi "restart"
    _json "d['systemMessage']" | grep -q "86%"
    [ "$(_json "d['hookSpecificOutput']['hookEventName']")" = "PreToolUse" ]
    _json "d['hookSpecificOutput']['additionalContext']" | grep -qi "tell the operator"
    _json "d['hookSpecificOutput']['additionalContext']" | grep -qi "natural break"
    _json "d['hookSpecificOutput']['additionalContext']" | grep -q "handover"
}

@test "urgent (slow path, transcript read): first call announces too" {
    _transcript "$TEST_TEMP_DIR/$ME.jsonl" 260000
    rm -f "$PROJ/.context/working/.budget-status"
    _gate "$ME" "$TEST_TEMP_DIR/$ME.jsonl" 0   # counter 0 -> this call re-reads
    [ "$(cat "$TEST_TEMP_DIR/rc")" -eq 0 ]
    grep -q '"level": "urgent"' "$PROJ/.context/working/.budget-status"
    _json "d['systemMessage']" | grep -qi "restart"
}

@test "urgent: announced once per session; a second call is stdout-silent; another session is announced" {
    _cache urgent 260000 "$ME"
    _gate "$ME"
    [ -s "$TEST_TEMP_DIR/out" ]
    _gate "$ME"
    [ ! -s "$TEST_TEMP_DIR/out" ]
    # stderr note still present for the transcript
    grep -q "WARNING: Context" "$TEST_TEMP_DIR/err"
    _cache urgent 260000 "$OTHER"
    _gate "$OTHER"
    [ -s "$TEST_TEMP_DIR/out" ]
}

@test "warn: first call emits a lighter operator message; urgent is still announced after warn" {
    _cache warn 230000 "$ME"
    _gate "$ME"
    [ "$(cat "$TEST_TEMP_DIR/rc")" -eq 0 ]
    _json "d['systemMessage']" | grep -q "76%"
    _json "d['systemMessage']" | grep -q "95%"
    _cache urgent 260000 "$ME"
    _gate "$ME"
    _json "d['systemMessage']" | grep -qi "restart"
}

@test "urgent: one fw_notify push, and dispatcher stdout does not leak into the hook JSON" {
    _cache urgent 260000 "$ME"
    _gate "$ME"
    _json "d['systemMessage']" >/dev/null   # stdout parses as JSON
    for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$DISPATCH_LOG" ] && break; sleep 0.2; done
    [ "$(wc -l < "$DISPATCH_LOG")" -eq 1 ]
    grep -qi "budget" "$DISPATCH_LOG"
    _gate "$ME"
    sleep 0.5
    [ "$(wc -l < "$DISPATCH_LOG")" -eq 1 ]
}

@test "warn: no push (urgent only)" {
    _cache warn 230000 "$ME"
    _gate "$ME"
    sleep 0.5
    [ ! -s "$DISPATCH_LOG" ]
}

@test "ok and critical are unchanged: ok silent, critical still blocks with no announcement JSON" {
    _cache ok 1000 "$ME"
    _gate "$ME"
    [ "$(cat "$TEST_TEMP_DIR/rc")" -eq 0 ]
    [ ! -s "$TEST_TEMP_DIR/out" ]
    _cache critical 290000 "$ME"
    export FW_CHECKPOINT_SH=/bin/true
    _gate "$ME"
    [ "$(cat "$TEST_TEMP_DIR/rc")" -eq 2 ]
    [ ! -s "$TEST_TEMP_DIR/out" ]
}
