#!/usr/bin/env bats
# T-5061 (G-130): on the Greenfield laptop .context/working/.checkpoint.handover.stderr reached
# 183 GB of one repeated handover block; the disk filled, WSL and the operator's Claude crashed.
# The writer was never localised (tail alone is bounded on GNU and uutils), so the fix bounds
# the files whatever writes them: the capture is a separate file, the background log is
# rotated and capped (head -c, SIGPIPE stops a runaway), and doctor/audit name oversized files.

load ../test_helper

BUDGET_GATE="$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
CHECKPOINT="$FRAMEWORK_ROOT/agents/context/checkpoint.sh"
ME="55555555-cccc-4ccc-8ccc-000000005061"

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working" "$TEST_TEMP_DIR/home"
    echo "session_id: S-TEST-5061" > "$PROJ/.context/working/session.yaml"
    BIG="$TEST_TEMP_DIR/$ME-big.jsonl"
    line='{"message":{"model":"claude-opus-5","usage":{"input_tokens":295000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
    printf '%s\n%s\n' "$line" "$line" > "$BIG"
    LOG="$PROJ/.context/working/.checkpoint.handover.stderr"
    # A runaway "checkpoint": prints the same push block forever (the 183 GB content).
    FLOOD="$TEST_TEMP_DIR/flood.sh"
    printf '#!/bin/bash\nwhile :; do printf "To ssh://x/repo\\n   dea63d7a..08b4b068  HEAD -> master\\nPushed to origin\\n"; done\n' > "$FLOOD"
    chmod +x "$FLOOD"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_gate() {   # $1 = stub checkpoint script
    echo 2 > "$PROJ/.context/working/.budget-gate-counter"
    [ -f "$PROJ/.context/working/.budget-status" ] || printf '{"level": "ok", "tokens": 0, "timestamp": %d, "session_id": "S-TEST-5061", "claude_session_id": "other", "source": "budget-gate"}' "$(date +%s)" > "$PROJ/.context/working/.budget-status"
    local input="{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$ME\",\"transcript_path\":\"$BIG\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"make build\"}}"
    run bash -c "printf '%s' '$input' | PROJECT_ROOT='$PROJ' CONTEXT_DIR='$PROJ/.context' HOME='$TEST_TEMP_DIR/home' FW_CONTEXT_WINDOW=300000 FW_HANDOVER_LOG_MAX_BYTES=4096 FW_CHECKPOINT_SH='$1' bash '$BUDGET_GATE'"
}

_wait_for() {   # $1 = grep pattern in $LOG
    local i
    for i in $(seq 1 50); do grep -q "$1" "$LOG" 2>/dev/null && return 0; sleep 0.2; done
    return 1
}

@test "T-5061: checkpoint.sh captures the handover into its own file, not the background log" {
    grep -q '_ah_capture="$CONTEXT_DIR/working/.checkpoint.handover.capture"' "$CHECKPOINT"
    [ "$(grep -c '_ah_capture="$CONTEXT_DIR/working/.checkpoint.handover.stderr"' "$CHECKPOINT")" -eq 0 ]
    grep -q 'head -c "$_ah_cap" >"$_ah_capture"' "$CHECKPOINT"
}

@test "T-5061: a runaway auto-handover writer is cut at the cap and the cut is recorded" {
    _gate "$FLOOD"
    [ "$status" -eq 2 ]
    _wait_for "auto-handover output cut at 4096 bytes"
    size=$(stat -c %s "$LOG")
    [ "$size" -lt 8192 ]
    sleep 1
    [ "$(stat -c %s "$LOG")" -eq "$size" ]   # nothing keeps writing after the cut
}

@test "T-5061: a log already over the cap is rotated to .1 before the next run" {
    head -c 10000 /dev/zero | tr '\0' 'x' > "$LOG"
    printf '#!/bin/bash\necho fresh-run\n' > "$TEST_TEMP_DIR/quiet.sh"
    chmod +x "$TEST_TEMP_DIR/quiet.sh"
    _gate "$TEST_TEMP_DIR/quiet.sh"
    _wait_for "fresh-run"
    [ "$(stat -c %s "$LOG.1")" -eq 10000 ]
    [ "$(stat -c %s "$LOG")" -lt 100 ]
}

@test "T-5061: doctor/audit helper names an oversized working file and skips databases" {
    source "$FRAMEWORK_ROOT/lib/working-oversize.sh"
    W="$PROJ/.context/working"
    truncate -s 3000000 "$W/.checkpoint.handover.stderr"
    truncate -s 3000000 "$W/fw-vec-index.db"
    truncate -s 1000 "$W/small.log"
    out=$(fw_working_oversized "$W" 2000000)
    [[ "$out" == "3000000 .checkpoint.handover.stderr" ]]
    [ -z "$(fw_working_oversized "$W" 5000000)" ]
    [ "$(fw_working_human_size 183610195968)" = "171.0G" ]
}

@test "T-5061: fw audit calls the oversize check" {
    grep -q 'fw_working_oversized "$CONTEXT_DIR/working"' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

# Behavioural, not a grep of the source: the first version passed a text check while
# doctor died on `CONTEXT_DIR: unbound variable` at this check and skipped every later one.
@test "T-5061: fw doctor names an oversized working file and runs on past the check" {
    mkdir -p "$PROJ/.tasks/active" "$PROJ/.tasks/completed"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    truncate -s 3000000 "$PROJ/.context/working/.checkpoint.handover.stderr"
    run bash -c "unset CONTEXT_DIR; FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJ' FW_WORKING_FILE_WARN_BYTES=2000000 timeout 300 '$FRAMEWORK_ROOT/bin/fw' doctor 2>&1"
    [[ "$output" != *"unbound variable"* ]]
    [[ "$output" == *"Oversized file(s) under .context/working/"* ]]
    [[ "$output" == *".context/working/.checkpoint.handover.stderr"* ]]
    # doctor reached its closing summary, so nothing after this check was skipped
    [[ "$output" == *"Project "*"warning(s)"* ]] || [[ "$output" == *"Project "*": healthy"* ]]
}
