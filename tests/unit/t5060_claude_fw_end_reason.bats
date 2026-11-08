#!/usr/bin/env bats
# T-5060 (055 msg d2628100): a claude-fw session that ends by a signal must say why.
#
# 055's wrapped Claude vanished at 20:51 with nothing on disk: the loop events
# (T-3182) are written only where `command claude` returns, and closing the window
# of a tmux-wrapped session (destroy-unattached, T-4003) sends HUP, which killed the
# wrapper before it wrote anything. These tests run the REAL wrapper with a stub
# `claude`: once as a real tmux pane whose session is destroyed, once killed by TERM.

export CLAUDE_FW_NO_SIDECAR=1   # T-3747: no always-on sidecar under a fixture

setup() {
    command -v tmux >/dev/null || skip "tmux unavailable"
    CFW="${BATS_TEST_DIRNAME}/../../bin/claude-fw"
    T="$(mktemp -d)"
    mkdir -p "$T/bin" "$T/proj/.context/working"
    git -C "$T/proj" init -q
    # stub claude: like the real one it reads its terminal, so it ends when the terminal
    # goes away (window closed) or on TERM. A stub that ignores the tty (sleep) outlives
    # the window: the kernel's HUP reaches only the pane's session leader, and bash runs
    # the wrapper's trap only once its foreground child has exited (measured, T-5060).
    # Plain cat, not `timeout cat`: timeout moves its child out of the terminal's
    # foreground group, where reading the tty stops it instead (measured).
    printf '#!/bin/bash\necho $$ > "%s/claude.pid"\necho stub-claude-up > "%s/up"\nexec cat >/dev/null\n' "$T" "$T" > "$T/bin/claude"
    chmod +x "$T/bin/claude"
    SOCK="t5060-$$-$BATS_TEST_NUMBER"
    LOG="$T/proj/.context/working/continuous-run.jsonl"
}

teardown() {
    tmux -L "${SOCK:-none}" kill-server 2>/dev/null || true
    [ -n "${T:-}" ] && rm -rf "$T"
}

_wait_file() {   # $1 file, $2 pattern
    local i
    for i in $(seq 1 100); do grep -q "$2" "$1" 2>/dev/null && return 0; sleep 0.1; done
    return 1
}

_env() {
    printf '%s ' env -u TMUX -u TL_CLAUDE_ENABLED -u FW_DISPATCHED_WORKER \
        CLAUDE_FW_NO_SIDECAR=1 FW_NO_TERMINATOR=1 FW_CLAUDE_FW_IN_TMUX=1 \
        PROJECT_ROOT="$T/proj" PATH="$T/bin:$PATH"
}

@test "T-5060: destroying the wrapped tmux session (window closed) records signal-hup" {
    tmux -L "$SOCK" -f /dev/null new-session -d -s w -c "$T/proj" "$(_env) bash '$CFW'"
    _wait_file "$T/up" stub-claude-up
    tmux -L "$SOCK" kill-session -t w        # what destroy-unattached does when the last client leaves
    _wait_file "$LOG" '"reason": "signal-hup"'
    line=$(grep '"reason": "signal-hup"' "$LOG")
    [[ "$line" == *'"event": "exit"'* ]]
    [[ "$line" == *'"exit_code": 129'* ]]
    [[ "$line" == *"terminal closed"* ]]
}

@test "T-5060: a TERM to the session (kill, shutdown) records signal-term" {
    cd "$T/proj"
    # own process group, so TERM reaches wrapper and stub claude together, as on shutdown
    # stdin from a FIFO nobody writes to keeps the stub cat waiting, like an idle claude
    mkfifo "$T/in"; exec 9<>"$T/in"
    setsid bash -c "$(_env) bash '$CFW' <'$T/in' >/dev/null 2>&1" &
    _wait_file "$T/up" stub-claude-up
    pgid=$(ps -o pgid= -p "$(cat "$T/claude.pid")" | tr -d ' ')
    [ -n "$pgid" ]
    kill -TERM -- "-$pgid"
    _wait_file "$LOG" '"reason": "signal-term"'
    grep '"reason": "signal-term"' "$LOG" | grep -q '"exit_code": 143'
}

@test "T-5060/control: a normal claude exit still records its own reason, not a signal" {
    printf '#!/bin/bash\nexit 0\n' > "$T/bin/claude"
    cd "$T/proj"
    run bash -c "$(_env) FW_NO_RESTART=1 timeout 60 bash '$CFW' --no-restart </dev/null"
    _wait_file "$LOG" '"event": "exit"'
    ! grep -q '"reason": "signal-' "$LOG"
}

@test "T-5060: claude-fw --help prints the launch modes and does not start claude" {
    run bash "$CFW" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--termlink"* ]]
    [[ "$output" == *"FW_CLAUDE_FW_NO_TMUX=1"* ]]
    [[ "$output" == *"continuous-run.jsonl"* ]]
    [ ! -f "$T/up" ]
    run bash "$CFW" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Launch modes"* ]]
}
