#!/usr/bin/env bats
# T-4003 (operator 2026-10-09): peer mail must reach every agent reliably. A bare terminal
# cannot be typed into from outside, so claude-fw re-launches a session that would land on one
# inside a private tmux session (status off, destroy-unattached), where the sidecar injector
# can find it by its tty (lib/sidecar/inject.py c2). These tests drive the real claude-fw with
# a fake tmux that records its argv.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CFW="$FRAMEWORK_ROOT/bin/claude-fw"
    T="$(mktemp -d)"
    mkdir -p "$T/bin"
    printf '#!/bin/bash\nprintf "%%s\\n" "$@" > %q\n' "$T/tmux.argv" > "$T/bin/tmux"
    chmod +x "$T/bin/tmux"
    command -v script >/dev/null || skip "script(1) unavailable (needed for a pty)"
}

teardown() { rm -rf "$T"; }

# Run claude-fw on a pseudo-terminal (script -qc), with the fake tmux first on PATH.
_run_tty() {
    run env -u TMUX -u FW_CLAUDE_FW_IN_TMUX -u FW_DISPATCHED_WORKER -u TL_CLAUDE_ENABLED \
        PATH="$T/bin:$PATH" "$@" script -qec "cd '$T' && timeout 10 bash '$CFW' -c" /dev/null
}

# The wrap decision alone, with no terminal and no launch.
_predicate() {
    eval "$(awk '/^_cfw_should_wrap_tmux\(\) \{/,/^}/' "$CFW")"
    _cfw_should_wrap_tmux
}

@test "T-4003: on a bare terminal claude-fw re-launches itself in a private tmux session" {
    _run_tty
    [ -s "$T/tmux.argv" ]
    head -1 "$T/tmux.argv" | grep -qx "new-session"
    grep -qx "FW_CLAUDE_FW_IN_TMUX=1" "$T/tmux.argv"
    grep -qx "$(readlink -f "$CFW")" "$T/tmux.argv"
    grep -qx -- "-c" "$T/tmux.argv"                   # the operator's own argument is passed on
    grep -qx "destroy-unattached" "$T/tmux.argv"
    grep -qx "status" "$T/tmux.argv"
    grep -q "^PATH=" "$T/tmux.argv"                  # the environment is carried over
}

@test "T-4003/control: inside tmux already (a fleet pane) there is no second wrap" {
    TMUX=/tmp/x,1,0 TERMLINK_ENABLED=0 HEADLESS=0 run _predicate
    [ "$status" -ne 0 ]
}

@test "T-4003/control: --termlink, headless, a dispatched worker or the opt-out are never wrapped" {
    unset TMUX
    TERMLINK_ENABLED=1 HEADLESS=0 run _predicate;                            [ "$status" -ne 0 ]
    TERMLINK_ENABLED=0 HEADLESS=1 run _predicate;                            [ "$status" -ne 0 ]
    FW_DISPATCHED_WORKER=1 TERMLINK_ENABLED=0 HEADLESS=0 run _predicate;     [ "$status" -ne 0 ]
    FW_CLAUDE_FW_NO_TMUX=1 TERMLINK_ENABLED=0 HEADLESS=0 run _predicate;     [ "$status" -ne 0 ]
    FW_CLAUDE_FW_IN_TMUX=1 TERMLINK_ENABLED=0 HEADLESS=0 run _predicate;     [ "$status" -ne 0 ]
}

@test "T-4003/control: without a terminal (stdin not a tty) there is no wrap" {
    unset TMUX
    TERMLINK_ENABLED=0 HEADLESS=0 run _predicate < /dev/null
    [ "$status" -ne 0 ]
}
