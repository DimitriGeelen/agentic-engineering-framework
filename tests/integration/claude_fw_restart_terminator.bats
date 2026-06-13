#!/usr/bin/env bats
# T-2372 — reproduction + (future) regression test for the continuous-mode
# budget-restart terminator gap.
#
# DEFECT (this test pins it): the claude-fw wrapper only checks the
# .restart-requested signal AFTER `claude` exits. At budget-critical,
# checkpoint.sh writes the signal but nothing terminates the running claude, so
# the (working) restart-on-exit logic is never reached.
#
# These tests drive the REAL bin/claude-fw wrapper with a STUB `claude` on PATH
# (no real claude tokens burned). Two cases isolate the defect:
#   - alive-stub  : stub writes the signal then BLOCKS  → wrapper must NOT restart
#                   while claude is alive (documents the bug; signal stays unconsumed).
#   - exiting-stub: stub writes the signal then EXITS   → wrapper restarts on exit
#                   (proves restart-on-exit works; isolates the defect to "no terminator").
#
# When the terminator fix lands in bin/claude-fw, add a third case
# (terminator-fires) asserting that an alive stub IS terminated on fresh signal
# and the restart branch executes.

setup() {
    FRAMEWORK_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    WRAPPER="$FRAMEWORK_ROOT/bin/claude-fw"
    [ -f "$WRAPPER" ] || skip "bin/claude-fw not found"
    command -v git >/dev/null || skip "git unavailable"

    PROJ="$(mktemp -d)"
    BINDIR="$(mktemp -d)"
    ( cd "$PROJ" && git init -q && git config user.email t@t && git config user.name t \
        && git commit -q --allow-empty -m init )
    mkdir -p "$PROJ/.context/working"
    SIG="$PROJ/.context/working/.restart-requested"
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

@test "BUG: alive claude at critical → wrapper does NOT restart (signal stays unconsumed)" {
    _make_stub "sleep 30"
    cd "$PROJ"
    # Wrapper should block on the alive stub; timeout kills it (non-zero rc).
    run timeout 8 env PATH="$BINDIR:$PATH" bash "$WRAPPER"
    # rc 124 (timeout) or 143 (SIGTERM) — the point is it did not return cleanly via restart.
    [ "$status" -ne 0 ]
    # No "Auto-restart" happened.
    [[ "$output" != *"Auto-restart #"* ]]
    # The signal was written but never consumed (wrapper never reached the rm/restart branch).
    [ -f "$SIG" ]
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
