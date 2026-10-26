#!/usr/bin/env bats
# T-4783 (055 T-640): check-tier0.sh had no rule for tmux kill-server /
# kill-session. An agent shell inside tmux has TMUX set, and tmux prefers it
# over TMUX_TMPDIR, so a scratch test that exported TMUX_TMPDIR still killed
# the shared server (055, 2026-10-26). A kill that names no -S/-L socket is
# Tier 0; one that names its own socket, and every non-kill tmux verb, passes.
#
# Never runs tmux: command strings are fed to the hook, as t3640 does.
# PROJECT_ROOT is a tempdir so a block's pending approval stays out of the
# real .context/ (L-256).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$TEST_TEMP_DIR/.context/approvals" "$TEST_TEMP_DIR/.context/working"
    HOOK="$FRAMEWORK_ROOT/agents/context/check-tier0.sh"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

_run_hook() {
    local json
    json=$(python3 -c "import json,sys; print(json.dumps({'tool_input':{'command': sys.argv[1]}}))" "$1")
    echo "$json" | bash "$HOOK"
}

_blocked() {
    run _run_hook "$1"
    if [ "$status" -ne 2 ]; then
        echo "expected block (2), got $status for: $1"
        return 1
    fi
    if ! printf '%s' "$output" | grep -q "TMUX KILL"; then
        echo "block message lacks 'TMUX KILL' for: $1"
        printf '%s\n' "$output" | head -12
        return 1
    fi
    if ! printf '%s' "$output" | grep -q -- "-S <socket>"; then
        echo "block message does not name -S/-L as the fix for: $1"
        return 1
    fi
}

_allowed() {
    run _run_hook "$1"
    if [ "$status" -ne 0 ]; then
        echo "expected allow (0), got $status for: $1"
        printf '%s\n' "$output" | head -12
        return 1
    fi
}

# ── Blocked: a kill that reaches whatever server TMUX points at ──

@test "bare tmux kill-server is blocked" {
    _blocked "tmux kill-server"
}

@test "bare tmux kill-session -t x is blocked" {
    _blocked "tmux kill-session -t x"
}

@test "chained after ; and && is blocked" {
    _blocked "echo start; tmux kill-server"
    _blocked "cd /tmp && tmux kill-session -t scratch"
}

@test "absolute path /usr/bin/tmux is blocked" {
    _blocked "/usr/bin/tmux kill-server"
}

@test "-f <config> names no socket and is blocked" {
    _blocked "tmux -f /tmp/scratch.conf kill-server"
}

@test "abbreviated verbs (kill-ses, kill-ser, kill-serv) are blocked" {
    for c in "tmux kill-ses -t x" "tmux kill-sess -t x" "tmux kill-ser" "tmux kill-serv" "tmux kill-serve"; do
        _blocked "$c"
    done
}

@test "TMUX_TMPDIR=... tmux kill-server is blocked (TMUX wins over TMUX_TMPDIR)" {
    _blocked "TMUX_TMPDIR=/tmp/scratch tmux kill-server"
}

# ── Allowed: an own socket, or a verb that kills nothing ──

@test "-S <socket> kill-server is allowed" {
    _allowed "tmux -S /tmp/scratch.sock kill-server"
    _allowed "tmux -S /tmp/scratch.sock kill-session -t x"
}

@test "-L <name> kill-server is allowed" {
    _allowed "tmux -L scratch kill-server"
}

@test "non-kill verbs are allowed" {
    _allowed "tmux ls"
    _allowed "tmux list-panes -a"
    _allowed "tmux capture-pane -p -t x"
}

@test "the phrase inside quoted text is allowed" {
    _allowed "echo 'never run tmux kill-server here'"
    _allowed "git commit -m \"T-4783: block tmux kill-server without -S\" -- x"
}

@test "kill-window and kill-pane are not in scope" {
    _allowed "tmux kill-pane -t x"
    _allowed "tmux kill-window -t x"
}
