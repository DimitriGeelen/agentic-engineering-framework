#!/usr/bin/env bats
# T-3918 (G-110, RC-1 of ring20-manager's T-2248) — the budget-critical
# terminator writes a handover before it ends the session.
# Measured: block 06:46:40Z, restart 06:46:41Z, no handover; the fresh session
# resumed from a 13 h-stale LATEST.md.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"
    ROOT="$T/proj"
    mkdir -p "$ROOT/.context/handovers" "$ROOT/.context/working" "$ROOT/bin"
    SIG="$ROOT/.context/working/.restart-requested"
    LOG="$ROOT/.context/working/.compact-log"
    # Fake fw: `handover --commit` writes LATEST.md (or fails / hangs on request).
    cat > "$ROOT/bin/fw" <<'SH'
#!/bin/bash
[ "$1" = handover ] || exit 9
case "${FAKE_HANDOVER:-ok}" in
    fail) exit 4 ;;
    hang) sleep 60 ;;
esac
echo "handover $(date +%s)" > "$PWD/.context/handovers/LATEST.md"
echo ran >> "$PWD/.context/working/.fake-ran"
SH
    chmod +x "$ROOT/bin/fw"
    # Pull the two functions out of claude-fw without running its main.
    eval "$(awk '/^_ensure_handover_before_kill\(\) \{/,/^}/' "$FRAMEWORK_ROOT/bin/claude-fw")"
    eval "$(awk '/^_terminator_watch\(\) \{/,/^}/' "$FRAMEWORK_ROOT/bin/claude-fw")"
    unset FAKE_HANDOVER FW_TERMINATOR_HANDOVER_TIMEOUT
}

teardown() {
    [ -n "${WRAP:-}" ] && kill "$WRAP" 2>/dev/null || true
    rm -rf "$T"
}

@test "T-3918: signal newer than LATEST.md -> a handover is written first and logged" {
    echo old > "$ROOT/.context/handovers/LATEST.md"
    touch -d "-1 hour" "$ROOT/.context/handovers/LATEST.md"
    run _ensure_handover_before_kill "$ROOT" "$(date +%s)"
    [ "$status" -eq 0 ]
    [ -f "$ROOT/.context/working/.fake-ran" ]
    grep -q "\[terminator\] Handover generated" "$LOG"
}

@test "T-3918: LATEST.md already newer than the signal -> no second handover, logged as skipped" {
    sig_mt=$(( $(date +%s) - 60 ))
    echo fresh > "$ROOT/.context/handovers/LATEST.md"
    run _ensure_handover_before_kill "$ROOT" "$sig_mt"
    [ "$status" -eq 0 ]
    [ ! -f "$ROOT/.context/working/.fake-ran" ]
    grep -q "\[terminator\] Handover skipped (fresh" "$LOG"
}

@test "T-3918: a failing handover is logged FAILED (fw doctor 5d reads it)" {
    export FAKE_HANDOVER=fail
    run _ensure_handover_before_kill "$ROOT" "$(date +%s)"
    [ "$status" -eq 1 ]
    grep -q "\[terminator\] Handover FAILED (rc=4)" "$LOG"
}

@test "T-3918: a hanging handover is cut at FW_TERMINATOR_HANDOVER_TIMEOUT" {
    export FAKE_HANDOVER=hang FW_TERMINATOR_HANDOVER_TIMEOUT=1
    start=$(date +%s)
    run _ensure_handover_before_kill "$ROOT" "$(date +%s)"
    [ "$status" -eq 1 ]
    [ $(( $(date +%s) - start )) -lt 15 ]
    grep -q "\[terminator\] Handover FAILED (rc=124)" "$LOG"
}

@test "T-3918: the terminator writes the handover BEFORE it kills the claude child, and still kills on failure" {
    export FAKE_HANDOVER=fail FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2
    # A fake wrapper whose only child is a long sleep standing in for claude.
    bash -c 'sleep 60 & wait' &
    WRAP=$!
    sleep 0.3
    run_start=$(( $(date +%s) - 1 ))
    echo '{}' > "$SIG"
    _terminator_watch "$WRAP" "$SIG" "$run_start"
    grep -q "\[terminator\] Handover FAILED" "$LOG"
    # The child is gone: the kill happened after the (failed) handover.
    sleep 0.3
    [ -z "$(pgrep -P "$WRAP" 2>/dev/null)" ]
}

@test "T-3918: budget-gate no longer claims claude -c preserves the conversation" {
    ! grep -q "Handover stays best-effort (claude -c" "$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
    grep -q "T-3918 (G-110)" "$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
}
