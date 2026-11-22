#!/usr/bin/env bats
# T-5361 — `checkpoint.sh budget` answered "level: unknown / cache is 362s old"
# mid-session. Two legs:
#   writer: budget-gate.sh throttled its transcript re-read to every 5th call even
#           once the cache was stale, so a stale cache stayed stale for minutes;
#   reader: when age is the cache's ONLY fault, `budget` measures live from THIS
#           Claude session's own transcript (found by session id, never "newest").
# A foreign cache or another session's transcript still yields unknown (T-3241, T-3598).
#
# Fixtures only: tmp PROJECT_ROOT, tmp HOME, synthetic transcripts and caches.

load ../test_helper

BUDGET_GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
CHECKPOINT="$FRAMEWORK_ROOT/agents/context/checkpoint.sh"

ME="11111111-aaaa-4aaa-8aaa-000000005361"
OTHER="22222222-bbbb-4bbb-8bbb-000000005361"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working"
    echo "session_id: S-TEST-5361" > "$PROJ/.context/working/session.yaml"
    TDIR="$TEST_TEMP_DIR/home/.claude/projects/$(printf '%s' "$PROJ" | tr -c 'a-zA-Z0-9' '-')"
    mkdir -p "$TDIR"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# _transcript FILE TOKENS [N] — N same-model usage entries (default 2: measured).
_transcript() {
    local f="$1" t="$2" n="${3:-2}" i
    : > "$f"
    for ((i = 0; i < n; i++)); do
        printf '{"message":{"model":"claude-opus-5","usage":{"input_tokens":%s,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' "$t" >> "$f"
    done
}

# _cache LEVEL TOKENS CLAUDE_SID AGE_SECONDS
_cache() {
    printf '{"level": "%s", "tokens": %s, "timestamp": %d, "session_id": "S-TEST-5361", "claude_session_id": "%s", "source": "budget-gate"}' \
        "$1" "$2" "$(( $(date +%s) - $4 ))" "$3" > "$PROJ/.context/working/.budget-status"
}

_budget() {
    run bash -c "PROJECT_ROOT='$PROJ' CONTEXT_DIR='$PROJ/.context' HOME='$TEST_TEMP_DIR/home' FW_CONTEXT_WINDOW=300000 CLAUDE_CODE_SESSION_ID='$ME' FW_TRANSCRIPT_PATH= bash '$CHECKPOINT' budget"
}

@test "T-5361 (1): stale cache + this session's own transcript gives a band, source transcript" {
    _cache ok 1000 "$ME" 400
    _transcript "$TDIR/$ME.jsonl" 50000
    _budget
    [ "$status" -eq 0 ]
    [[ "$output" == *"level: ok"* ]]
    [[ "$output" == *"tokens: 50000"* ]]
    [[ "$output" == *"source: transcript (cache was 4"*"s old)"* ]]
    [[ "$output" == *"free_tokens: 250000"* ]]
    [[ "$output" == *"band: Green"* ]]
    [[ "$output" != *"level: unknown"* ]]
}

@test "T-5361 (2): stale cache + only ANOTHER session's transcript gives unknown, not its number" {
    _cache ok 1000 "$ME" 400
    _transcript "$TDIR/$OTHER.jsonl" 50000   # newest file, but not ours
    _budget
    [ "$status" -eq 0 ]
    [[ "$output" == *"level: unknown"* ]]
    [[ "$output" == *"s old (max 90s)"* ]]
    [[ "$output" == *"no transcript for this Claude session"* ]]
    [[ "$output" != *"band:"* ]]
    [[ "$output" != *"tokens: 50000"* ]]
    [[ "$output" != *"stale_age"* ]]
}

@test "T-5361 (2b): a foreign cache is not 'age only' and never reaches the live path" {
    _cache ok 1000 "$OTHER" 400
    _transcript "$TDIR/$ME.jsonl" 50000
    _budget
    [[ "$output" == *"level: unknown"* ]]
    [[ "$output" == *"not this one ($ME)"* ]]
    [[ "$output" != *"band:"* ]]
}

@test "T-5361 (3): a young own transcript gives the young line, level unknown" {
    _cache ok 1000 "$ME" 400
    _transcript "$TDIR/$ME.jsonl" 30000 1
    _budget
    [ "$status" -eq 0 ]
    [[ "$output" == *"level: unknown"* ]]
    [[ "$output" == *"not yet measured since this session (re)started (newest provisional reading: 30000)"* ]]
    [[ "$output" == *"source: transcript"* ]]
    [[ "$output" != *"band:"* ]]
}

@test "T-5361 (4): a fresh cache is read as before (no transcript involved)" {
    _cache warn 250000 "$ME" 5
    _transcript "$TDIR/$ME.jsonl" 50000   # would say Green; must be ignored
    _budget
    [ "$status" -eq 0 ]
    [[ "$output" == *"level: warn"* ]]
    [[ "$output" == *"tokens: 250000"* ]]
    [[ "$output" == *"free_tokens: 50000"* ]]
    [[ "$output" == *"band: Amber"* ]]
    [[ "$output" != *"source: transcript"* ]]
}

@test "T-5361 writer: a stale cache is re-read on an off-interval gate call (no 1-in-5 throttle)" {
    _cache ok 1000 "$ME" 400
    _transcript "$TDIR/$ME.jsonl" 50000
    echo 2 > "$PROJ/.context/working/.budget-gate-counter"   # 2 % 5 != 1: the old throttle skipped
    local input="{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$ME\",\"transcript_path\":\"$TDIR/$ME.jsonl\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"make build\"}}"
    run bash -c "printf '%s' '$input' | PROJECT_ROOT='$PROJ' CONTEXT_DIR='$PROJ/.context' HOME='$TEST_TEMP_DIR/home' FW_CONTEXT_WINDOW=300000 bash '$BUDGET_GATE'"
    [ "$status" -eq 0 ]
    run python3 -c "import json,time; s=json.load(open('$PROJ/.context/working/.budget-status')); print(s['tokens'], int(time.time())-s['timestamp'])"
    [[ "$output" == "50000 "* ]]
    [ "${output#* }" -lt 10 ]
}
