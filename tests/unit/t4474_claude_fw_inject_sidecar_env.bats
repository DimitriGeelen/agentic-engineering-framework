#!/usr/bin/env bats
# T-4474 — the line claude-fw injects into a TermLink PTY must hand the arc-011
# sidecar sockets (TERMLINK_SIDECAR_SOCKET / _STATUS_SOCKET) to the claude it
# launches. The PTY shell is spawned by termlink, not by claude-fw, and termlink
# >= 0.12.665 no longer forwards them (010-termlink T-3464, pickup offset 342).
#
# The injected line and the prefix helper are taken from bin/claude-fw's own
# source, rendered with the sockets set or unset, and run in an `env -i` bash
# (no sockets in its environment, as in the PTY) with a stand-in claude binary.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"
    mkdir -p "$T/bin"
    cat > "$T/bin/claude" <<EOF
#!/bin/bash
printf 'S=%s\n' "\${TERMLINK_SIDECAR_SOCKET-<unset>}" > "$T/seen"
printf 'T=%s\n' "\${TERMLINK_SIDECAR_STATUS_SOCKET-<unset>}" >> "$T/seen"
printf 'A=%s\n' "\$@" >> "$T/seen"
exit 0
EOF
    chmod +x "$T/bin/claude"
    INJECT_SRC=$(grep -E '^[[:space:]]*termlink_inject "[^"]*command claude\$\{_tl_args\}' "$REPO/bin/claude-fw")
    ENV_SRC=$(grep -E '^[[:space:]]*_tl_env=\$\(_tl_sidecar_env_prefix\)' "$REPO/bin/claude-fw")
    HELPER_SRC=$(sed -n '/^_tl_sidecar_env_prefix() {/,/^}/p' "$REPO/bin/claude-fw")
    [ -n "$INJECT_SRC" ]
}

teardown() { rm -rf "$T"; }

# Render the injected text the way claude-fw builds it, in the caller's env.
_injected_line() {
    local CLAUDE_ARGS=("$@") restart_count=0 _tl_args="" _tl_env="" _tl_tok
    [ "${#CLAUDE_ARGS[@]}" -gt 0 ] && _tl_args=$(printf ' %q' "${CLAUDE_ARGS[@]}")
    eval "$HELPER_SRC"
    eval "$ENV_SRC"
    _tl_tok="r0p1e1"
    termlink_inject() { printf '%s\n' "$1"; }
    eval "$INJECT_SRC"
}

_run_in_pty_shell() {
    printf '%s\nexit\n' "$1" | env -i HOME="$T" PATH="$T/bin:/usr/bin:/bin" bash --norc -i 2>/dev/null
}

@test "T-4474: set sockets reach the launched claude, quoted as data" {
    line=$(TERMLINK_SIDECAR_SOCKET='/run/tl/side car.sock' TERMLINK_SIDECAR_STATUS_SOCKET='/run/$HOME/st;x.sock' _injected_line)
    out=$(_run_in_pty_shell "$line")
    [ "$(sed -n 1p "$T/seen")" = 'S=/run/tl/side car.sock' ]
    [ "$(sed -n 2p "$T/seen")" = 'T=/run/$HOME/st;x.sock' ]
    printf '%s\n' "$out" | grep -q '__CLAUDE_FW_EXIT_r0p1e1_0__'
}

@test "T-4474: unset sockets add nothing to the line" {
    line=$(unset TERMLINK_SIDECAR_SOCKET TERMLINK_SIDECAR_STATUS_SOCKET; _injected_line)
    case "$line" in "command claude;"*) ;; *) echo "line: $line"; false ;; esac
    _run_in_pty_shell "$line" >/dev/null
    [ "$(sed -n 1p "$T/seen")" = 'S=<unset>' ]
    [ "$(sed -n 2p "$T/seen")" = 'T=<unset>' ]
}

@test "T-4474: only one socket set passes only that one, args still one word each" {
    line=$(unset TERMLINK_SIDECAR_STATUS_SOCKET; TERMLINK_SIDECAR_SOCKET=/s.sock _injected_line --resume "two words")
    _run_in_pty_shell "$line" >/dev/null
    [ "$(sed -n 1p "$T/seen")" = 'S=/s.sock' ]
    [ "$(sed -n 2p "$T/seen")" = 'T=<unset>' ]
    [ "$(sed -n 3p "$T/seen")" = 'A=--resume' ]
    [ "$(sed -n 4p "$T/seen")" = 'A=two words' ]
}
