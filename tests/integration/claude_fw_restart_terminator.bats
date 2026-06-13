#!/usr/bin/env bats
# T-2372 (repro) + T-2373 (fix) — continuous-mode budget-restart terminator.
#
# DEFECT (T-2372): the claude-fw wrapper only checked the .restart-requested
# signal AFTER `claude` exits. At budget-critical, checkpoint.sh writes the signal
# but nothing terminated the running claude, so the (working) restart-on-exit
# logic was never reached.
#
# FIX (T-2373): a background terminator watcher runs alongside foreground claude;
# on a FRESH signal written during the run it SIGTERMs/SIGKILLs claude so the
# restart-on-exit branch fires. FW_NO_TERMINATOR=1 opts out.
#
# These tests drive the REAL bin/claude-fw wrapper with a STUB `claude` on PATH
# (no real claude tokens burned). Three cases bound the behavior:
#   - terminator-fires : alive stub at critical → watcher ends it → wrapper restarts.
#   - CONTROL          : stub exits with fresh signal → wrapper restarts on exit.
#   - opt-out          : FW_NO_TERMINATOR=1 + alive stub → NOT terminated, no restart
#                        (pins the pre-fix behavior as the documented opt-out).
#
# Poll/grace are tuned down via env so the harness runs in seconds.

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    WRAPPER="$FRAMEWORK_ROOT/bin/claude-fw"
    [ -f "$WRAPPER" ] || skip "bin/claude-fw not found"
    command -v git >/dev/null || skip "git unavailable"
    command -v pgrep >/dev/null || skip "pgrep unavailable"

    PROJ="$(mktemp -d)"
    BINDIR="$(mktemp -d)"
    ( cd "$PROJ" && git init -q && git config user.email t@t && git config user.name t \
        && git commit -q --allow-empty -m init )
    mkdir -p "$PROJ/.context/working"
    SIG="$PROJ/.context/working/.restart-requested"
    # Fast terminator so the test doesn't take 50s.
    export FW_TERMINATOR_POLL=1
    export FW_TERMINATOR_GRACE=1
}

teardown() {
    [ -n "${PROJ:-}" ] && rm -rf "$PROJ"
    [ -n "${BINDIR:-}" ] && rm -rf "$BINDIR"
}

# $1 = stub tail action ("sleep 30" or "exit 0")
_make_stub() {
    cat > "$BINDIR/claude" <<STUB
#!/bin/bash
sig="\$(git rev-parse --show-toplevel)/.context/working/.restart-requested"
echo '{"timestamp":"now","session_id":"stub","reason":"critical_budget_auto_handover","tokens":99999}' > "\$sig"
echo "STUB-CLAUDE-RAN"
$1
STUB
    chmod +x "$BINDIR/claude"
}

@test "FIX: alive claude at critical → terminator ends it → wrapper restarts" {
    _make_stub "sleep 30"
    cd "$PROJ"
    # With the terminator, each run is killed shortly after it writes the signal,
    # so the wrapper restarts repeatedly until MAX_RESTARTS(5).
    run timeout 60 env PATH="$BINDIR:$PATH" \
        FW_TERMINATOR_POLL=1 FW_TERMINATOR_GRACE=1 bash "$WRAPPER"
    [[ "$output" == *"budget-critical signal detected"* ]]
    [[ "$output" == *"Auto-restart #1"* ]]
    [[ "$output" == *"Max restarts"* ]]
    # Signal consumed (removed) on the final iteration.
    [ ! -f "$SIG" ]
}

@test "CONTROL: claude exits with fresh signal → wrapper restarts on exit" {
    _make_stub "exit 0"
    cd "$PROJ"
    # Stub exits immediately each run → wrapper restarts until MAX_RESTARTS(5).
    run timeout 40 env PATH="$BINDIR:$PATH" bash "$WRAPPER"
    [[ "$output" == *"Auto-restart #1"* ]]
    [[ "$output" == *"Max restarts"* ]]
    # Signal consumed (removed) by the restart path on the final iteration.
    [ ! -f "$SIG" ]
}

@test "OPT-OUT: FW_NO_TERMINATOR=1 + alive claude → not terminated, no restart" {
    _make_stub "sleep 30"
    cd "$PROJ"
    # Opt-out restores pre-fix behavior: wrapper blocks on the alive stub; timeout
    # kills it (non-zero rc), no restart, signal stays unconsumed.
    run timeout 8 env PATH="$BINDIR:$PATH" FW_NO_TERMINATOR=1 bash "$WRAPPER"
    [ "$status" -ne 0 ]
    [[ "$output" != *"Auto-restart #"* ]]
    [[ "$output" != *"budget-critical signal detected"* ]]
    [ -f "$SIG" ]
}
