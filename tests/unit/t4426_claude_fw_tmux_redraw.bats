#!/usr/bin/env bats
# T-4426 (ring20-dashboard proposal): after a mouse-wheel scroll into tmux copy mode, on attach
# and on resize, Claude Code's screen stays cluttered until Ctrl+L. claude-fw's tmux chain now
# sets three hooks that send C-l to the wrapped session's pane. They are scoped to that session
# (or its window), never -g: the fw-agents server also carries dispatch workers.
#
# The static leg runs the real claude-fw with a fake tmux that records its argv. The live leg
# takes the set-hook groups from that recorded argv and replays them on a throwaway tmux server
# with a unique -L name, so it exercises the hook strings claude-fw emits, not a copy of them.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CFW="$FRAMEWORK_ROOT/bin/claude-fw"
    T="$(mktemp -d)"
    mkdir -p "$T/bin"
    printf '#!/bin/bash\nprintf "%%s\\n" "$@" > %q\n' "$T/tmux.argv" > "$T/bin/tmux"
    chmod +x "$T/bin/tmux"
    command -v script >/dev/null || skip "script(1) unavailable (needed for a pty)"
    SOCK=""
}

teardown() {
    # The live leg's own server, and nothing else: its socket name is unique to this test.
    [ -n "$SOCK" ] && tmux -L "$SOCK" kill-server >/dev/null 2>&1 || true
    rm -rf "$T"
}

# Run claude-fw on a pseudo-terminal (script -qc), with the fake tmux first on PATH.
_run_tty() {
    run env -u TMUX -u FW_CLAUDE_FW_IN_TMUX -u FW_DISPATCHED_WORKER -u TL_CLAUDE_ENABLED \
        PATH="$T/bin:$PATH" "$@" script -qec "cd '$T' && timeout 10 bash '$CFW' -c" /dev/null
}

@test "T-4426: the wrap chain sets three session-scoped redraw hooks, none of them -g" {
    _run_tty
    [ -s "$T/tmux.argv" ]
    mapfile -t ARGV < "$T/tmux.argv"
    # The session name is the -s value of new-session; the hooks must target that session.
    local name="" i
    for ((i = 0; i < ${#ARGV[@]}; i++)); do
        [ "${ARGV[$i]}" = "-s" ] && { name="${ARGV[$((i + 1))]}"; break; }
    done
    [ -n "$name" ]
    # Every set-hook group, as argv elements up to the chain's ';' separator.
    local groups
    groups="$(awk '/^set-hook$/{on=1; print "--"; next} /^;$/{on=0} on{print}' "$T/tmux.argv")"
    [ "$(grep -c '^--$' <<< "$groups")" -eq 3 ]
    grep -qx "pane-mode-changed" <<< "$groups"
    grep -qx "client-attached" <<< "$groups"
    grep -qx "client-resized" <<< "$groups"
    # Scoped: no set-hook is global, and the window hook targets the session's window.
    ! grep -qx -- "-g" <<< "$groups" || false
    grep -qx -- "$name:" <<< "$groups"
    grep -qx -- "$name" <<< "$groups"
    # The mode guard is the format check, and the commands reuse the server name claude-fw uses.
    grep -q '\[ #{pane_in_mode} = 0 \]' "$T/tmux.argv"
    [ "$(grep -c -- '-L fw-agents send-keys -t #{pane_id} C-l' "$T/tmux.argv")" -eq 3 ]
}

@test "T-4426: live, copy mode ending sends ^L to the wrapped pane only (throwaway server)" {
    command -v tmux >/dev/null 2>&1 || skip "tmux unavailable"
    _run_tty
    [ -s "$T/tmux.argv" ]
    mapfile -t ARGV < "$T/tmux.argv"
    SOCK="t4426-$$-${BATS_TEST_NUMBER:-0}"
    local name="" i
    for ((i = 0; i < ${#ARGV[@]}; i++)); do
        [ "${ARGV[$i]}" = "-s" ] && { name="${ARGV[$((i + 1))]}"; break; }
    done
    [ -n "$name" ]

    # Wrapped session (the name claude-fw chose) and a second session, both running `cat -v`,
    # on a server with no user config. cat -v prints a received Ctrl+L as ^L.
    tmux -L "$SOCK" -f /dev/null new-session -d -s "$name" -x 80 -y 20 'cat -v'
    tmux -L "$SOCK" -f /dev/null new-session -d -s other -x 80 -y 20 'cat -v'

    # Replay each recorded set-hook group against the throwaway server. The socket name in the
    # recorded commands is swapped for this test's unique one; the session target is unchanged.
    local g=() replayed=0
    for ((i = 0; i < ${#ARGV[@]}; i++)); do
        if [ "${ARGV[$i]}" = "set-hook" ]; then
            g=()
            i=$((i + 1))
            while [ "$i" -lt "${#ARGV[@]}" ] && [ "${ARGV[$i]}" != ";" ]; do
                g+=("${ARGV[$i]//fw-agents/$SOCK}")
                i=$((i + 1))
            done
            tmux -L "$SOCK" "set-hook" "${g[@]}"
            replayed=$((replayed + 1))
        fi
    done
    [ "$replayed" -eq 3 ]

    # Enter copy mode in the wrapped pane and leave it again (copy-mode -q exits every mode).
    tmux -L "$SOCK" copy-mode -t "$name:"
    sleep 0.5
    [ "$(tmux -L "$SOCK" display -p -t "$name:" '#{pane_in_mode}')" != 0 ]
    tmux -L "$SOCK" copy-mode -q -t "$name:"
    sleep 1.5

    # The wrapped pane received Ctrl+L; the other session's pane did not.
    tmux -L "$SOCK" capture-pane -p -t "$name:" > "$T/wrapped.txt"
    tmux -L "$SOCK" capture-pane -p -t "other:" > "$T/other.txt"
    grep -q '\^L' "$T/wrapped.txt"
    ! grep -q '\^L' "$T/other.txt" || false
}

@test "T-4426/control: a copy-mode entry alone sends no ^L (the pane_in_mode guard)" {
    command -v tmux >/dev/null 2>&1 || skip "tmux unavailable"
    _run_tty
    mapfile -t ARGV < "$T/tmux.argv"
    SOCK="t4426c-$$-${BATS_TEST_NUMBER:-0}"
    local name="" i
    for ((i = 0; i < ${#ARGV[@]}; i++)); do
        [ "${ARGV[$i]}" = "-s" ] && { name="${ARGV[$((i + 1))]}"; break; }
    done
    tmux -L "$SOCK" -f /dev/null new-session -d -s "$name" -x 80 -y 20 'cat -v'
    for ((i = 0; i < ${#ARGV[@]}; i++)); do
        if [ "${ARGV[$i]}" = "set-hook" ]; then
            local g=()
            i=$((i + 1))
            while [ "$i" -lt "${#ARGV[@]}" ] && [ "${ARGV[$i]}" != ";" ]; do
                g+=("${ARGV[$i]//fw-agents/$SOCK}")
                i=$((i + 1))
            done
            tmux -L "$SOCK" "set-hook" "${g[@]}"
        fi
    done
    tmux -L "$SOCK" copy-mode -t "$name:"
    sleep 1.5
    tmux -L "$SOCK" capture-pane -p -t "$name:" > "$T/entered.txt"
    ! grep -q '\^L' "$T/entered.txt" || false
}
