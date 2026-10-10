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
    eval "$(awk '/^_turn_state\(\) \{/,/^}/' "$FRAMEWORK_ROOT/bin/claude-fw")"
    export FW_TERMINATOR_IDLE_SETTLE=1
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

# ── T-4032 (1409, 5th hard cutoff): never end a session mid-turn ─────────────
# budget-gate writes the signal on the FIRST critical block; the terminator used
# to kill on first sight, 3 s later, mid-turn. It now ends the session only at the
# end of THIS session's turn (its own record in .context/sidecar/sessions/, matched
# by claude_pid), held for FW_TERMINATOR_IDLE_SETTLE, or at FW_TERMINATOR_MAX_WAIT.
# Every foreground call runs in a subshell: the function starts with `set +e`, which
# in the test's own shell switches off errexit and makes the assertions after it
# inert (that is how the original T-3918 kill test passed on code it did not test).

_fake_wrapper() { bash -c 'sleep 60 & wait' & WRAP=$!; sleep 0.3; CHILD=$(pgrep -P "$WRAP" | head -1); }
# _session READY [AGE_SECONDS] [PID] — this session's record (Stop: true, UserPromptSubmit: false)
_session() {
    local ready="$1" age="${2:-0}" pid="${3:-$CHILD}"
    mkdir -p "$ROOT/.context/sidecar/sessions"
    touch -d "-$((age + 1)) seconds" "$T/transcript.jsonl"
    python3 -c 'import json,sys,datetime as d
r,age,pid,tp,out=sys.argv[1:6]
ts=(d.datetime.now(d.timezone.utc)-d.timedelta(seconds=int(age))).isoformat()
json.dump({"session_id":"s-"+pid,"transcript_path":tp,"claude_pid":int(pid),"ready":r=="true","updated_at":ts},open(out,"w"))' \
        "$ready" "$age" "$pid" "$T/transcript.jsonl" "$ROOT/.context/sidecar/sessions/s-$pid.json"
}
_watch_bg() { _terminator_watch "$WRAP" "$SIG" "$(( $(date +%s) - 1 ))" & TW=$!; }
_alive() { [ -n "$(pgrep -P "$WRAP" 2>/dev/null)" ]; }
_stop_bg() { kill "$TW" 2>/dev/null || true; }

@test "T-3918: the terminator writes the handover BEFORE it kills the claude child, and still kills on failure" {
    export FAKE_HANDOVER=fail FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2
    _fake_wrapper
    echo '{}' > "$SIG"
    sleep 1; _session true                  # T-4032: the turn has ended
    ( _terminator_watch "$WRAP" "$SIG" "$(( $(date +%s) - 5 ))" )
    grep -q "\[terminator\] Handover FAILED" "$LOG"
    sleep 0.3
    ! _alive || false
}

@test "T-4032: a fresh signal while the turn is still running does NOT kill" {
    export FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2 FW_TERMINATOR_MAX_WAIT=60
    _fake_wrapper; _session false
    echo '{}' > "$SIG"
    _watch_bg; sleep 3
    _alive                                   # pre-T-4032: dead within one 0.2 s poll
    _stop_bg
    grep -q "waiting for the turn to end" "$LOG"
}

@test "T-4032: an idle record written BEFORE the signal does not count as the turn ending" {
    export FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2 FW_TERMINATOR_MAX_WAIT=60
    _fake_wrapper; _session true 120
    echo '{}' > "$SIG"
    _watch_bg; sleep 3
    _alive
    _stop_bg
}

@test "T-4032: ANOTHER session going idle (and the project-wide flag) does not end this one" {
    export FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2 FW_TERMINATOR_MAX_WAIT=60
    _fake_wrapper; _session false
    echo '{}' > "$SIG"
    sleep 1; _session true 0 999999          # a worker / second session ends its turn
    printf 'ready: true\n' > "$ROOT/.context/sidecar/ready-for-input.yaml"
    _watch_bg; sleep 3
    _alive
    _stop_bg
}

@test "T-4032: a Stop that another hook rejected (transcript still moving) does not end the session" {
    export FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2 FW_TERMINATOR_MAX_WAIT=60
    _fake_wrapper
    echo '{}' > "$SIG"
    sleep 1; _session true 10                # ready written 10 s ago ...
    touch "$T/transcript.jsonl"              # ... but the turn kept writing after it
    _watch_bg; sleep 3
    _alive
    _stop_bg
}

@test "T-4032: when this session's turn ends, it ends after a handover, and the restart signal is kept fresh" {
    export FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2 FW_TERMINATOR_MAX_WAIT=60
    _fake_wrapper; _session false
    echo '{}' > "$SIG"
    touch -d "-200 seconds" "$SIG"           # an old-ish signal: the wait must not let it expire
    ( sleep 1.5; _session true ) &
    ( _terminator_watch "$WRAP" "$SIG" "$(( $(date +%s) - 300 ))" )
    grep -q "\[terminator\] Handover generated" "$LOG"
    [ $(( $(date +%s) - $(stat -c %Y "$SIG") )) -lt 10 ]   # refreshed before the kill
    sleep 0.3
    ! _alive || false
}

@test "T-4032: a turn that never ends is cut at FW_TERMINATOR_MAX_WAIT (no dead-lock)" {
    export FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2 FW_TERMINATOR_MAX_WAIT=2
    _fake_wrapper; _session false
    echo '{}' > "$SIG"
    start=$(date +%s)
    ( _terminator_watch "$WRAP" "$SIG" "$(( start - 1 ))" )
    [ $(( $(date +%s) - start )) -ge 2 ]
    grep -q "turn did not end within 2s" "$LOG"
    sleep 0.3
    ! _alive || false
}

@test "T-4032: no session record (hooks not wired) waits for the ceiling, never ends early" {
    export FW_TERMINATOR_POLL=0.2 FW_TERMINATOR_GRACE=0.2 FW_TERMINATOR_MAX_WAIT=60
    _fake_wrapper
    printf 'ready: true\n' > "$ROOT/.context/sidecar/ready-for-input.yaml" 2>/dev/null || { mkdir -p "$ROOT/.context/sidecar"; printf 'ready: true\n' > "$ROOT/.context/sidecar/ready-for-input.yaml"; }
    echo '{}' > "$SIG"
    _watch_bg; sleep 3
    _alive
    _stop_bg
    grep -q "no session record" "$LOG"
}

@test "T-3918: budget-gate no longer claims claude -c preserves the conversation" {
    run grep -q "Handover stays best-effort (claude -c" "$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
    [ "$status" -eq 1 ]
    grep -q "T-3918 (G-110)" "$FRAMEWORK_ROOT/agents/context/budget-gate.sh"
}
