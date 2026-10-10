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
    _idle                                   # T-4032: the turn has ended
    # In a subshell: the function starts with `set +e`, which in the test's own
    # shell would switch off errexit and make every assertion below inert (T-4032
    # found this test passing on code that did not do what it asserts).
    ( _terminator_watch "$WRAP" "$SIG" "$run_start" )
    grep -q "\[terminator\] Handover FAILED" "$LOG"
    # The child is gone: the kill happened after the (failed) handover.
    sleep 0.3
    [ -z "$(pgrep -P "$WRAP" 2>/dev/null)" ]
}

# ── T-4032 (1409, 5th hard cutoff): never end a session mid-turn ─────────────
# budget-gate writes the signal on the FIRST critical block; the terminator used
# to kill on first sight, 3 s later, mid-turn. It now waits for the Stop hook's
# idle flag (written at or after the signal), or a hard ceiling.

_idle() { mkdir -p "$ROOT/.context/sidecar"; printf 'ready: true\n' > "$ROOT/.context/sidecar/ready-for-input.yaml"; }
_busy() { mkdir -p "$ROOT/.context/sidecar"; printf 'ready: false\n' > "$ROOT/.context/sidecar/ready-for-input.yaml"; }
_fake_wrapper() { bash -c 'sleep 60 & wait' & WRAP=$!; sleep 0.3; }

@test "T-4032: a fresh signal while the turn is still running does NOT kill" {
    export FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2 FW_TERMINATOR_MAX_WAIT=60
    _fake_wrapper
    _busy
    echo '{}' > "$SIG"
    _terminator_watch "$WRAP" "$SIG" "$(( $(date +%s) - 1 ))" &
    TW=$!
    sleep 3
    # Pre-T-4032 the child was dead within one 0.2 s poll.
    [ -n "$(pgrep -P "$WRAP" 2>/dev/null)" ]
    kill "$TW" 2>/dev/null || true
    grep -q "waiting for the turn to end" "$LOG"
}

@test "T-4032: a stale idle flag (from before the signal) does not count as the turn ending" {
    export FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2 FW_TERMINATOR_MAX_WAIT=60
    _fake_wrapper
    _idle
    touch -d "-2 minutes" "$ROOT/.context/sidecar/ready-for-input.yaml"
    echo '{}' > "$SIG"
    _terminator_watch "$WRAP" "$SIG" "$(( $(date +%s) - 1 ))" &
    TW=$!
    sleep 2
    [ -n "$(pgrep -P "$WRAP" 2>/dev/null)" ]
    kill "$TW" 2>/dev/null || true
}

@test "T-4032: when the turn ends after the signal, the session ends (after the handover)" {
    export FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2 FW_TERMINATOR_MAX_WAIT=60
    _fake_wrapper
    _busy
    echo '{}' > "$SIG"
    ( sleep 1.5; _idle ) &
    ( _terminator_watch "$WRAP" "$SIG" "$(( $(date +%s) - 1 ))" )
    grep -q "\[terminator\] Handover generated" "$LOG"
    sleep 0.3
    [ -z "$(pgrep -P "$WRAP" 2>/dev/null)" ]
}

@test "T-4032: a turn that never ends is cut at FW_TERMINATOR_MAX_WAIT (no dead-lock)" {
    export FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2 FW_TERMINATOR_MAX_WAIT=2
    _fake_wrapper
    _busy
    echo '{}' > "$SIG"
    start=$(date +%s)
    ( _terminator_watch "$WRAP" "$SIG" "$(( start - 1 ))" )
    [ $(( $(date +%s) - start )) -ge 2 ]
    grep -q "turn did not end within 2s" "$LOG"
    sleep 0.3
    [ -z "$(pgrep -P "$WRAP" 2>/dev/null)" ]
}

@test "T-3918: budget-gate no longer claims claude -c preserves the conversation" {
    run grep -q "Handover stays best-effort (claude -c" "$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
    [ "$status" -eq 1 ]
    grep -q "T-3918 (G-110)" "$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
}
