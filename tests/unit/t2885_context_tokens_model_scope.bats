#!/usr/bin/env bats
# T-2885 — budget-gate.sh and checkpoint.sh both took the LAST usage entry in
# the transcript as this conversation's context size. Four models write usage
# entries into one transcript; a foreign-model cache-priming call can land
# after our own last turn and report its own huge prompt as ours (832 T-401).
#
# Fix: lib/context_tokens.py scopes usage entries to the model with the MOST
# entries since the last compact_boundary (the dominant writer), not to the
# newest entry's model. Below two in-scope entries it returns 0 rather than
# guess.
#
# TEETH: tests/fixtures/T-2885/poisoning-transcript.jsonl is built from a real
# poisoning-shaped entry (see README in that dir). This file pins BOTH sides:
# the pre-fix algorithm (frozen copy, below) must still return the inflated
# 252178 on the fixture — proving the fixture keeps reproducing the bug — and
# the shared fix must return the real 84629.

load ../test_helper

FIXTURE="$FRAMEWORK_ROOT/tests/fixtures/T-2885/poisoning-transcript.jsonl"
MODULE="$FRAMEWORK_ROOT/lib/context_tokens.py"

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Frozen copy of the PRE-FIX algorithm (last raw usage entry wins, no model
# scoping) — exists ONLY to prove the fixture still reproduces the bug it was
# built to reproduce. Not used by any production caller.
_legacy_last_entry_tokens() {
    local file="$1"
    python3 -c "
import json
t = 0
with open('$file') as f:
    for line in f:
        try:
            e = json.loads(line)
        except Exception:
            continue
        if e.get('type') == 'system' and e.get('subtype') == 'compact_boundary':
            t = 0
            continue
        model = e.get('message', {}).get('model', '')
        if model == '<synthetic>' or model.startswith('<'):
            continue
        u = e.get('message', {}).get('usage')
        if u and 'input_tokens' in u:
            t = u['input_tokens'] + u.get('cache_read_input_tokens', 0) + u.get('cache_creation_input_tokens', 0)
print(t)
"
}

_fixed_tokens() {  # file [session_start_ts]
    python3 "$MODULE" "${2:-}" < "$1"
}

# --- TEETH: fixture reproduces the bug on the pre-fix algorithm ---

@test "TEETH: pre-fix algorithm still returns the poisoned 252178 on the fixture" {
    result="$(_legacy_last_entry_tokens "$FIXTURE")"
    [ "$result" = "252178" ]
}

# --- Fix: dominant-model scoping recovers the real size ---

@test "fix: dominant-model scoping returns the real 84629, not the poisoned 252178" {
    result="$(_fixed_tokens "$FIXTURE")"
    [ "$result" = "84629" ]
}

# --- Under two in-scope entries: fail open to 0, not a guess ---

@test "fix: a single usage entry (only 1 in-scope) returns 0" {
    f="$TEST_TEMP_DIR/single.jsonl"
    printf '%s\n' '{"message":{"model":"claude-opus-5","usage":{"input_tokens":50000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}' > "$f"
    result="$(_fixed_tokens "$f")"
    [ "$result" = "0" ]
}

@test "fix: a lone foreign entry right after a boundary (poisoning shape, 1 in-scope) returns 0, not the foreign total" {
    f="$TEST_TEMP_DIR/lone-foreign.jsonl"
    printf '%s\n' '{"message":{"model":"claude-opus-4-8","usage":{"input_tokens":2,"cache_read_input_tokens":0,"cache_creation_input_tokens":300000}}}' > "$f"
    result="$(_fixed_tokens "$f")"
    [ "$result" = "0" ]
}

@test "fix: zero usage entries returns 0" {
    f="$TEST_TEMP_DIR/empty.jsonl"
    : > "$f"
    result="$(_fixed_tokens "$f")"
    [ "$result" = "0" ]
}

# --- A genuinely oversized session still reads critical (fix repairs, doesn't remove) ---

@test "fix: a genuinely oversized dominant-model session still reports the real high total" {
    f="$TEST_TEMP_DIR/oversized.jsonl"
    cat > "$f" <<'EOF'
{"message":{"model":"claude-opus-5","usage":{"input_tokens":200000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
{"message":{"model":"claude-opus-5","usage":{"input_tokens":250000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
{"message":{"model":"claude-opus-5","usage":{"input_tokens":290000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
EOF
    result="$(_fixed_tokens "$f")"
    [ "$result" = "290000" ]
    # Threshold check mirrors budget-gate.sh's TOKEN_CRITICAL at the 300K default window (95%)
    [ "$result" -ge 285000 ]
}

@test "fix: end-to-end — budget-gate.sh blocks on the fixture's real size, not the poisoned one" {
    PROJECT_ROOT="$TEST_TEMP_DIR/proj"
    CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$CONTEXT_DIR/working"
    echo "0" > "$CONTEXT_DIR/working/.budget-gate-counter"
    HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"

    input="{\"hook_event_name\":\"PreToolUse\",\"transcript_path\":\"$FIXTURE\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"/src/main.py\"}}"
    run bash -c "printf '%s' '$input' | PROJECT_ROOT='$PROJECT_ROOT' CONTEXT_DIR='$CONTEXT_DIR' HOME='$HOME' FW_CONTEXT_WINDOW=300000 bash '$FRAMEWORK_ROOT/agents/context/budget-gate.sh'"

    # 84629 tokens on a 300K window is well under critical (285K) — allowed, not blocked.
    # If the bug were present (252178 taken as ours, still under 285K here) this would
    # also pass; the discriminating assertion is the status file's token value below.
    [ "$status" -eq 0 ]
    tokens_written="$(python3 -c "import json; print(json.load(open('$CONTEXT_DIR/working/.budget-status'))['tokens'])")"
    [ "$tokens_written" = "84629" ]
}

# --- checkpoint.sh gains the compact_boundary reset it never had (AC) ---

@test "checkpoint.sh get_context_tokens resets on compact_boundary (was missing pre-T-2885)" {
    f="$TEST_TEMP_DIR/boundary.jsonl"
    cat > "$f" <<'EOF'
{"message":{"model":"claude-opus-5","usage":{"input_tokens":290000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
{"type":"system","subtype":"compact_boundary"}
{"message":{"model":"claude-opus-5","usage":{"input_tokens":10000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
{"message":{"model":"claude-opus-5","usage":{"input_tokens":15000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
EOF
    PROJECT_ROOT="$TEST_TEMP_DIR/proj2"
    CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$CONTEXT_DIR/working"
    run env PROJECT_ROOT="$PROJECT_ROOT" CONTEXT_DIR="$CONTEXT_DIR" FW_TRANSCRIPT_PATH="$f" \
        bash "$FRAMEWORK_ROOT/agents/context/checkpoint.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"15000"* ]]
    [[ "$output" != *"290000"* ]]
}
