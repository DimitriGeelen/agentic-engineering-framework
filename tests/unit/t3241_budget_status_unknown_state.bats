#!/usr/bin/env bats
# T-3241 — budget-gate.sh wrote {"level":"ok","tokens":0} for THREE distinct
# situations that are NOT a healthy fresh session: (1) fewer than 2 dominant-model
# usage entries since the last compact boundary (context_tokens.py's own "return 0
# rather than guess" path), (2) no transcript found at all, (3) the transcript scan
# crashing outright (e.g. UnicodeDecodeError on invalid UTF-8 during line
# iteration — folded in from an external field report, 001-CashWeb T-222/G-087,
# via T-3264). All three collapsed into the identical on-disk shape as a genuinely
# healthy zero-usage session, which the /resume protocol treats as canonical.
#
# Fix: context_tokens.py's --with-model output already carries the "was this
# confidently measured" signal (model=="" on every give-up path, non-empty only
# for a real dominant-model measurement). budget-gate.sh now reads --with-model
# and writes an honest {"level":"unknown","tokens":null} instead of a fabricated
# ok/0 whenever the model field is empty — covering all three trigger paths with
# one signal, no per-path special-casing. Every write branch also stamps
# session_id, and checkpoint.sh gains a `budget` subcommand that refuses to echo
# a plausible-looking but untrustworthy cached level (unknown-marked, stale, or
# written by a different session).

load ../test_helper

BUDGET_GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
CHECKPOINT="$FRAMEWORK_ROOT/agents/context/checkpoint.sh"

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# run_gate LABEL TRANSCRIPT — fresh PROJECT_ROOT/CONTEXT_DIR per call (the gate
# skips its own slow path on GATE_COUNT % RECHECK_INTERVAL != 1, so reusing one
# CONTEXT_DIR across calls in the same test silently serves a stale cached
# result instead of re-scanning — verified while writing this file).
run_gate() {
    local label="$1" transcript="$2"
    local proj="$TEST_TEMP_DIR/$label"
    mkdir -p "$proj/.context/working"
    echo "0" > "$proj/.context/working/.budget-gate-counter"
    cat > "$proj/.context/working/session.yaml" <<'EOF'
session_id: S-TEST-0001
EOF
    local home="$TEST_TEMP_DIR/home-$label"
    mkdir -p "$home"
    local input="{\"hook_event_name\":\"PreToolUse\",\"transcript_path\":\"$transcript\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"/src/main.py\"}}"
    run bash -c "printf '%s' '$input' | PROJECT_ROOT='$proj' CONTEXT_DIR='$proj/.context' HOME='$home' FW_CONTEXT_WINDOW=300000 bash '$BUDGET_GATE'"
    STATUS_JSON="$(cat "$proj/.context/working/.budget-status" 2>/dev/null || echo '{}')"
}

# --- Trigger path 1: scan crash (invalid UTF-8) -> unknown, not fabricated ok/0 ---

@test "crash: transcript with invalid UTF-8 bytes writes level=unknown, tokens=null (not ok/0)" {
    f="$TEST_TEMP_DIR/bad-utf8.jsonl"
    printf '\xff\xfe this is not valid utf8\n{"message":{"model":"claude-opus-5","usage":{"input_tokens":100,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' > "$f"
    run_gate "crash" "$f"
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"level": "unknown"'
    echo "$STATUS_JSON" | grep -q '"tokens": null'
}

# --- Control: a genuinely confident zero measurement still writes real ok/0 ---

@test "control: two same-model entries with all-zero usage fields still write real level=ok, tokens=0" {
    f="$TEST_TEMP_DIR/honest-zero.jsonl"
    cat > "$f" <<'EOF'
{"message":{"model":"claude-opus-5","usage":{"input_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
{"message":{"model":"claude-opus-5","usage":{"input_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
EOF
    run_gate "honest-zero" "$f"
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"level": "ok"'
    echo "$STATUS_JSON" | grep -q '"tokens": 0'
}

# --- Trigger path 2 (T-3241 original filing): fewer than 2 in-scope entries ---

@test "underfilled: a single usage entry (only 1 in-scope) writes level=unknown, not ok/0" {
    f="$TEST_TEMP_DIR/single.jsonl"
    printf '%s\n' '{"message":{"model":"claude-opus-5","usage":{"input_tokens":50000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}' > "$f"
    run_gate "underfilled" "$f"
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"level": "unknown"'
}

@test "underfilled: zero usage entries in the transcript writes level=unknown, not ok/0" {
    f="$TEST_TEMP_DIR/empty.jsonl"
    : > "$f"
    run_gate "empty" "$f"
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"level": "unknown"'
}

# --- Trigger path 3 (T-3241 original filing): no transcript found at all ---

@test "no-transcript: an untraceable/nonexistent transcript path writes level=unknown, not a silent no-op leaving a stale ok cache" {
    proj="$TEST_TEMP_DIR/no-transcript"
    mkdir -p "$proj/.context/working"
    echo "0" > "$proj/.context/working/.budget-gate-counter"
    echo "session_id: S-TEST-0001" > "$proj/.context/working/session.yaml"
    # Seed a pre-existing, STALE "ok" cache (older than STATUS_MAX_AGE so the
    # fast path falls through to the slow path we're testing) to prove it gets
    # overwritten rather than silently left in place — the exact gap T-3241
    # named: "nothing anywhere emits 'I could not measure'".
    printf '{"level": "ok", "tokens": 5000, "timestamp": %d, "session_id": "S-TEST-0001", "source": "budget-gate"}' "$(($(date +%s) - 200))" > "$proj/.context/working/.budget-status"
    home="$TEST_TEMP_DIR/home-no-transcript"
    mkdir -p "$home"
    input='{"hook_event_name":"PreToolUse","transcript_path":"/nonexistent/path.jsonl","tool_name":"Write","tool_input":{"file_path":"/src/main.py"}}'
    run bash -c "printf '%s' '$input' | PROJECT_ROOT='$proj' CONTEXT_DIR='$proj/.context' HOME='$home' FW_CONTEXT_WINDOW=300000 bash '$BUDGET_GATE'"
    [ "$status" -eq 0 ]
    STATUS_JSON="$(cat "$proj/.context/working/.budget-status")"
    echo "$STATUS_JSON" | grep -q '"level": "unknown"'
    echo "$STATUS_JSON" | grep -q '"session_id": "S-TEST-0001"'
}

# --- A genuine confident measurement still enforces normally ---

@test "confident: a real dominant-model measurement still reports the real level and blocks appropriately" {
    f="$TEST_TEMP_DIR/confident.jsonl"
    cat > "$f" <<'EOF'
{"message":{"model":"claude-opus-5","usage":{"input_tokens":200000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
{"message":{"model":"claude-opus-5","usage":{"input_tokens":250000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
EOF
    run_gate "confident" "$f"
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"level": "warn"'
    echo "$STATUS_JSON" | grep -q '"tokens": 250000'
}

# --- session_id is stamped on every write branch ---

@test "session_id: is present in the cache on both the unknown branch and the real-measurement branch" {
    f_unknown="$TEST_TEMP_DIR/single2.jsonl"
    printf '%s\n' '{"message":{"model":"claude-opus-5","usage":{"input_tokens":50000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}' > "$f_unknown"
    run_gate "sid-unknown" "$f_unknown"
    echo "$STATUS_JSON" | grep -q '"session_id": "S-TEST-0001"'

    f_ok="$TEST_TEMP_DIR/confident2.jsonl"
    cat > "$f_ok" <<'EOF'
{"message":{"model":"claude-opus-5","usage":{"input_tokens":10000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
{"message":{"model":"claude-opus-5","usage":{"input_tokens":12000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
EOF
    run_gate "sid-ok" "$f_ok"
    echo "$STATUS_JSON" | grep -q '"session_id": "S-TEST-0001"'
}

# --- unknown level still fails open (no case arm blocks on it) ---

@test "unknown level does not block the tool call (fails open, same as the pre-existing no-transcript path)" {
    f="$TEST_TEMP_DIR/single3.jsonl"
    printf '%s\n' '{"message":{"model":"claude-opus-5","usage":{"input_tokens":50000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}' > "$f"
    run_gate "failopen" "$f"
    [ "$status" -eq 0 ]
}

# --- checkpoint.sh budget: safe reader ---

_write_status() {  # dir level tokens age_offset_seconds session_id
    local dir="$1" level="$2" tokens="$3" age_offset="$4" sid="$5"
    mkdir -p "$dir/.context/working"
    local ts=$(( $(date +%s) - age_offset ))
    printf '{"level": "%s", "tokens": %s, "timestamp": %d, "session_id": "%s", "source": "budget-gate"}' \
        "$level" "$tokens" "$ts" "$sid" > "$dir/.context/working/.budget-status"
}

@test "checkpoint budget: writer-marked unknown cache reports level unknown with a reason" {
    proj="$TEST_TEMP_DIR/cp-unknown"
    _write_status "$proj" "unknown" "null" 5 "S-OWN"
    echo "session_id: S-OWN" > "$proj/.context/working/session.yaml"
    run env PROJECT_ROOT="$proj" CONTEXT_DIR="$proj/.context" bash "$CHECKPOINT" budget
    [ "$status" -eq 0 ]
    [[ "$output" == *"level: unknown"* ]]
    [[ "$output" == *"reason:"* ]]
}

@test "checkpoint budget: stale cache (older than STATUS_MAX_AGE) reports unknown with a reason" {
    proj="$TEST_TEMP_DIR/cp-stale"
    _write_status "$proj" "ok" "1000" 999 "S-OWN"
    echo "session_id: S-OWN" > "$proj/.context/working/session.yaml"
    run env PROJECT_ROOT="$proj" CONTEXT_DIR="$proj/.context" bash "$CHECKPOINT" budget
    [ "$status" -eq 0 ]
    [[ "$output" == *"level: unknown"* ]]
    [[ "$output" == *"cache is"*"old"* ]]
}

@test "checkpoint budget: foreign-session cache reports unknown with a reason" {
    proj="$TEST_TEMP_DIR/cp-foreign"
    _write_status "$proj" "ok" "1000" 5 "S-OTHER-SESSION"
    echo "session_id: S-OWN" > "$proj/.context/working/session.yaml"
    run env PROJECT_ROOT="$proj" CONTEXT_DIR="$proj/.context" bash "$CHECKPOINT" budget
    [ "$status" -eq 0 ]
    [[ "$output" == *"level: unknown"* ]]
    [[ "$output" == *"written by session S-OTHER-SESSION"* ]]
}

# --- Control: a fresh, valid, own-session cache passes through cleanly ---

@test "control: checkpoint budget passes a fresh valid own-session cache through cleanly" {
    proj="$TEST_TEMP_DIR/cp-clean"
    _write_status "$proj" "warn" "230000" 5 "S-OWN"
    echo "session_id: S-OWN" > "$proj/.context/working/session.yaml"
    run env PROJECT_ROOT="$proj" CONTEXT_DIR="$proj/.context" bash "$CHECKPOINT" budget
    [ "$status" -eq 0 ]
    [[ "$output" == *"level: warn"* ]]
    [[ "$output" == *"tokens: 230000"* ]]
    [[ "$output" != *"unknown"* ]]
}

@test "checkpoint budget: missing cache file reports unknown, not an error" {
    proj="$TEST_TEMP_DIR/cp-missing"
    mkdir -p "$proj/.context/working"
    run env PROJECT_ROOT="$proj" CONTEXT_DIR="$proj/.context" bash "$CHECKPOINT" budget
    [ "$status" -eq 0 ]
    [[ "$output" == *"level: unknown"* ]]
    [[ "$output" == *"no cache file"* ]]
}
