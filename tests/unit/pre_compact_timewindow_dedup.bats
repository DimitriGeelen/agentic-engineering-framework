#!/usr/bin/env bats
# T-1478 — pre-compact.sh layers a time-window dedup on top of flock to
# catch SEQUENTIAL dual-fires that flock alone cannot stop. When both
# user-level and project-level PreCompact hooks register, /compact may
# invoke them sequentially (A finishes before B starts). Without time-window
# dedup, B will run a fresh handover and produce duplicate content.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---- Source-level invariants ----

@test "pre-compact.sh defines PRE_COMPACT_DEDUP_FILE (T-1478)" {
    grep -q 'PRE_COMPACT_DEDUP_FILE=' "$FRAMEWORK_ROOT/agents/context/pre-compact.sh"
}

@test "pre-compact.sh defines PRE_COMPACT_DEDUP_WINDOW with numeric value (T-1478)" {
    grep -qE 'PRE_COMPACT_DEDUP_WINDOW=[0-9]+' "$FRAMEWORK_ROOT/agents/context/pre-compact.sh"
}

@test "pre-compact.sh writes the timestamp file after gating (T-1478)" {
    # The script must echo $now > $DEDUP_FILE on a fresh run
    grep -qE 'echo .*_pre_compact_now.*>.*PRE_COMPACT_DEDUP_FILE' "$FRAMEWORK_ROOT/agents/context/pre-compact.sh"
}

@test "pre-compact.sh exits silently when last run was within window (T-1478)" {
    # Pattern: if (now - last) < window, exit 0
    grep -qE '_pre_compact_now - _pre_compact_last' "$FRAMEWORK_ROOT/agents/context/pre-compact.sh"
}

# ---- Behavioural: simulate the dedup logic in isolation ----

@test "second invocation within window exits early (sequential dual-fire)" {
    cd "$TEST_TEMP_DIR"
    DEDUP_FILE="$TEST_TEMP_DIR/.last-run"
    DEDUP_WINDOW=30
    NOW=$(date +%s)
    # Simulate: previous run wrote timestamp 5s ago
    echo $((NOW - 5)) > "$DEDUP_FILE"
    # Apply the dedup check from pre-compact.sh
    SHOULD_EXIT=false
    if [ -f "$DEDUP_FILE" ]; then
        _last=$(cat "$DEDUP_FILE" 2>/dev/null)
        if [ -n "$_last" ] && [ "$_last" -gt 0 ] 2>/dev/null && \
           [ $((NOW - _last)) -lt "$DEDUP_WINDOW" ]; then
            SHOULD_EXIT=true
        fi
    fi
    [ "$SHOULD_EXIT" = "true" ]
}

@test "first invocation (no prior file) proceeds (T-1478)" {
    cd "$TEST_TEMP_DIR"
    DEDUP_FILE="$TEST_TEMP_DIR/.last-run"
    DEDUP_WINDOW=30
    NOW=$(date +%s)
    SHOULD_EXIT=false
    if [ -f "$DEDUP_FILE" ]; then
        SHOULD_EXIT=true  # never reached
    fi
    [ "$SHOULD_EXIT" = "false" ]
}

@test "invocation after window expired proceeds (T-1478)" {
    cd "$TEST_TEMP_DIR"
    DEDUP_FILE="$TEST_TEMP_DIR/.last-run"
    DEDUP_WINDOW=30
    NOW=$(date +%s)
    # Previous run was 60s ago — well outside 30s window
    echo $((NOW - 60)) > "$DEDUP_FILE"
    SHOULD_EXIT=false
    if [ -f "$DEDUP_FILE" ]; then
        _last=$(cat "$DEDUP_FILE" 2>/dev/null)
        if [ -n "$_last" ] && [ "$_last" -gt 0 ] 2>/dev/null && \
           [ $((NOW - _last)) -lt "$DEDUP_WINDOW" ]; then
            SHOULD_EXIT=true
        fi
    fi
    [ "$SHOULD_EXIT" = "false" ]
}

@test "garbage in dedup file does not abort the script (defensive)" {
    cd "$TEST_TEMP_DIR"
    DEDUP_FILE="$TEST_TEMP_DIR/.last-run"
    DEDUP_WINDOW=30
    NOW=$(date +%s)
    echo "not-a-number" > "$DEDUP_FILE"
    # The actual check uses 2>/dev/null on the -gt comparison, so an invalid
    # value should fall through (treat as "no recent run").
    SHOULD_EXIT=false
    if [ -f "$DEDUP_FILE" ]; then
        _last=$(cat "$DEDUP_FILE" 2>/dev/null)
        if [ -n "$_last" ] && [ "$_last" -gt 0 ] 2>/dev/null && \
           [ $((NOW - _last)) -lt "$DEDUP_WINDOW" ]; then
            SHOULD_EXIT=true
        fi
    fi
    [ "$SHOULD_EXIT" = "false" ]
}

# ---- Sanity ----

@test "pre-compact.sh parses (bash -n) (T-1478)" {
    bash -n "$FRAMEWORK_ROOT/agents/context/pre-compact.sh"
}
