#!/usr/bin/env bats
# T-3248 — useful-headroom measurement (arc-012 E9). The budget gauge reports
# tokens against WINDOW, but the work a session can actually do per iteration is
# WINDOW - BASELINE: the floor a fresh session pays for CLAUDE.md, hooks and the
# injected handover before its first useful turn, re-paid in full on every
# restart. E9 measured a 52.6k floor against a 58000 cap — ~4% of the window
# available to work in — with no gauge anywhere showing it.
#
# What ships: BASELINE derived from the session's OWN transcript (first in-scope
# usage entry of the dominant model since the last compact_boundary — mirror of
# lib/context_tokens.py's scoping, which takes the LAST entry for current usage);
# baseline_tokens / headroom_tokens / headroom_ratio ride along in the
# .budget-status cache write; `checkpoint.sh status` prints a Useful-headroom
# line. Measurement ONLY — no threshold, gate, or WARN (AC 5); the constrained
# case here asserts exit 0 to pin that.
#
# Hermetic: fixture JSONL transcripts + scratch PROJECT_ROOT/CONTEXT_DIR per
# test. Never depends on the live session's transcript.

load ../test_helper

CHECKPOINT="$FRAMEWORK_ROOT/agents/context/checkpoint.sh"
BUDGET_GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    TEST_TEMP_DIR="$(mktemp -d)"

    # "Heavy config" session: first turn already carries 52,600 tokens
    # (100 input + 500 cache_read + 52,000 cache_creation) — the E9 shape.
    HEAVY="$TEST_TEMP_DIR/heavy.jsonl"
    cat > "$HEAVY" <<'EOF'
{"timestamp":"2026-09-07T10:00:00.000Z","message":{"model":"claude-fable-5","usage":{"input_tokens":100,"cache_read_input_tokens":500,"cache_creation_input_tokens":52000,"output_tokens":50}}}
{"timestamp":"2026-09-07T10:01:00.000Z","message":{"model":"claude-fable-5","usage":{"input_tokens":200,"cache_read_input_tokens":52600,"cache_creation_input_tokens":200,"output_tokens":50}}}
EOF

    # "Light config" session: same model, first turn carries only 12,000.
    LIGHT="$TEST_TEMP_DIR/light.jsonl"
    cat > "$LIGHT" <<'EOF'
{"timestamp":"2026-09-07T10:00:00.000Z","message":{"model":"claude-fable-5","usage":{"input_tokens":100,"cache_read_input_tokens":400,"cache_creation_input_tokens":11500,"output_tokens":50}}}
{"timestamp":"2026-09-07T10:01:00.000Z","message":{"model":"claude-fable-5","usage":{"input_tokens":100,"cache_read_input_tokens":12000,"cache_creation_input_tokens":400,"output_tokens":50}}}
EOF
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# run_baseline LABEL TRANSCRIPT — fresh scratch CONTEXT_DIR so the per-session
# .session-baseline cache of one call cannot leak into another.
run_baseline() {
    local label="$1" transcript="$2"
    local proj="$TEST_TEMP_DIR/bl-$label"
    mkdir -p "$proj/.context/working"
    run env PROJECT_ROOT="$proj" CONTEXT_DIR="$proj/.context" HOME="$TEST_TEMP_DIR" \
        bash "$CHECKPOINT" baseline "$transcript"
}

# run_gate LABEL TRANSCRIPT WINDOW — fresh PROJECT_ROOT per call (the gate skips
# its own slow path on GATE_COUNT % RECHECK_INTERVAL != 1 — same discipline as
# t3241_budget_status_unknown_state.bats).
run_gate() {
    local label="$1" transcript="$2" window="$3"
    GATE_PROJ="$TEST_TEMP_DIR/gate-$label"
    mkdir -p "$GATE_PROJ/.context/working"
    echo "0" > "$GATE_PROJ/.context/working/.budget-gate-counter"
    echo "session_id: S-T3248" > "$GATE_PROJ/.context/working/session.yaml"
    local input="{\"hook_event_name\":\"PreToolUse\",\"transcript_path\":\"$transcript\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"/src/main.py\"}}"
    run bash -c "printf '%s' '$input' | PROJECT_ROOT='$GATE_PROJ' CONTEXT_DIR='$GATE_PROJ/.context' HOME='$TEST_TEMP_DIR' FW_CONTEXT_WINDOW=$window bash '$BUDGET_GATE'"
    STATUS_JSON="$(cat "$GATE_PROJ/.context/working/.budget-status" 2>/dev/null || echo '{}')"
}

# --- AC 1: BASELINE is measured per session, not a constant ---

@test "baseline: heavy-config fixture reports its own first-turn floor (52600)" {
    run_baseline "heavy" "$HEAVY"
    [ "$status" -eq 0 ]
    [ "$output" = "52600" ]
}

@test "baseline: light-config fixture reports a DIFFERENT, lower floor (12000) — derived, not constant" {
    run_baseline "light" "$LIGHT"
    [ "$status" -eq 0 ]
    [ "$output" = "12000" ]
    [ "$output" != "52600" ]
}

@test "baseline: fewer than 2 in-scope entries reports 0 (not yet measurable), never a guess" {
    single="$TEST_TEMP_DIR/single.jsonl"
    printf '%s\n' '{"message":{"model":"claude-fable-5","usage":{"input_tokens":100,"cache_read_input_tokens":0,"cache_creation_input_tokens":49900}}}' > "$single"
    run_baseline "single" "$single"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "baseline: a compact_boundary resets it — the post-compact session re-pays the floor" {
    bounded="$TEST_TEMP_DIR/bounded.jsonl"
    cat > "$bounded" <<'EOF'
{"message":{"model":"claude-fable-5","usage":{"input_tokens":100,"cache_read_input_tokens":0,"cache_creation_input_tokens":39900}}}
{"message":{"model":"claude-fable-5","usage":{"input_tokens":100,"cache_read_input_tokens":40000,"cache_creation_input_tokens":900}}}
{"type":"system","subtype":"compact_boundary"}
{"message":{"model":"claude-fable-5","usage":{"input_tokens":50,"cache_read_input_tokens":0,"cache_creation_input_tokens":17950}}}
{"message":{"model":"claude-fable-5","usage":{"input_tokens":50,"cache_read_input_tokens":18000,"cache_creation_input_tokens":450}}}
EOF
    run_baseline "bounded" "$bounded"
    [ "$status" -eq 0 ]
    [ "$output" = "18000" ]   # first POST-boundary entry, not the pre-compact 40000
}

# --- AC 3: figure is machine-readable from .budget-status ---

@test "budget-status: baseline_tokens, headroom_tokens, headroom_ratio present alongside level and tokens" {
    run_gate "fields" "$HEAVY" 300000
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"level": "ok"'
    echo "$STATUS_JSON" | grep -q '"tokens": 53000'
    echo "$STATUS_JSON" | grep -q '"baseline_tokens": 52600'
    echo "$STATUS_JSON" | grep -q '"headroom_tokens": 247400'
    echo "$STATUS_JSON" | grep -q '"headroom_ratio": 0.82'
}

@test "budget-status: unknown-measurement branch writes null headroom fields, never a fabricated number" {
    single="$TEST_TEMP_DIR/single2.jsonl"
    printf '%s\n' '{"message":{"model":"claude-fable-5","usage":{"input_tokens":100,"cache_read_input_tokens":0,"cache_creation_input_tokens":49900}}}' > "$single"
    run_gate "nulls" "$single" 300000
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"level": "unknown"'
    echo "$STATUS_JSON" | grep -q '"baseline_tokens": null'
    echo "$STATUS_JSON" | grep -q '"headroom_ratio": null'
}

@test "budget reader (checkpoint.sh budget) passes the headroom fields through" {
    run_gate "reader" "$HEAVY" 300000
    run env PROJECT_ROOT="$GATE_PROJ" CONTEXT_DIR="$GATE_PROJ/.context" HOME="$TEST_TEMP_DIR" \
        bash "$CHECKPOINT" budget
    [ "$status" -eq 0 ]
    [[ "$output" == *"baseline_tokens: 52600"* ]]
    [[ "$output" == *"headroom_tokens: 247400"* ]]
    [[ "$output" == *"headroom_ratio: 0.82"* ]]
}

# --- AC 2: readable from an existing surface (checkpoint.sh status) ---

@test "status surface: prints a Useful-headroom line with headroom, baseline, and ratio" {
    proj="$TEST_TEMP_DIR/status-proj"
    mkdir -p "$proj/.context/working"
    run env PROJECT_ROOT="$proj" CONTEXT_DIR="$proj/.context" HOME="$TEST_TEMP_DIR" \
        FW_TRANSCRIPT_PATH="$HEAVY" FW_CONTEXT_WINDOW=300000 bash "$CHECKPOINT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Useful headroom: 247400 tokens"* ]]
    [[ "$output" == *"baseline 52600"* ]]
    [[ "$output" == *"ratio 0.82"* ]]
}

# --- AC 4: negative control — the measurement MOVES between configurations ---

@test "negative control: constrained window (58000, the E9 dial) reports a visibly poor ratio" {
    run_gate "constrained" "$HEAVY" 58000
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"headroom_tokens": 5400'
    echo "$STATUS_JSON" | grep -q '"headroom_ratio": 0.09'
}

@test "negative control: default window (300000) reports a healthy ratio against the same session" {
    run_gate "default" "$HEAVY" 300000
    [ "$status" -eq 0 ]
    echo "$STATUS_JSON" | grep -q '"headroom_ratio": 0.82'
    ! echo "$STATUS_JSON" | grep -q '"headroom_ratio": 0.09'
}

# --- AC 5: measurement only — a poor ratio gates NOTHING ---

@test "no gate ships: the poor-ratio constrained run still exits 0 and mentions no headroom threshold" {
    run_gate "nogate" "$HEAVY" 58000
    [ "$status" -eq 0 ]   # urgent level warns about TOKENS, but headroom itself blocks nothing
    [[ "$output" != *"headroom"* ]]   # no headroom-based WARN text on the gate's stderr
}
