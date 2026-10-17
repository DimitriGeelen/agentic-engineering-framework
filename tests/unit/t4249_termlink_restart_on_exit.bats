#!/usr/bin/env bats
# T-4249 — claude-fw --termlink must honour .restart-requested when claude EXITS on its own.
#
# 055 (0506-Voxtype-extention, 2026-10-17 16:23) and 1409 (15:00:36): after the budget-critical
# auto-handover wrote .restart-requested and claude ended, claude-fw did not relaunch claude in
# the same TermLink session — it exited 0 and its cleanup typed `exit` into the TermLink shell.
#
# Drives the REAL bin/claude-fw --termlink with a fake `claude` on PATH that writes the restart
# signal on its first run and exits. Everything lives in a private tmux server (-L <unique>),
# a private TMUX_TMPDIR and a private TERMLINK_RUNTIME_DIR: no shared tmux or termlink session
# is touched, and teardown removes only what this test created.

export CLAUDE_FW_NO_SIDECAR=1

setup() {
    command -v tmux >/dev/null || skip "tmux unavailable"
    command -v termlink >/dev/null || skip "termlink unavailable"
    CFW="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/bin/claude-fw"
    T="$(mktemp -d)"
    SOCK="t4249-$$-$RANDOM"
    mkdir -p "$T/bin" "$T/rt" "$T/tmx" "$T/home" "$T/repo/.context/working"
    # The TermLink shell is interactive: its startup files rewrite PATH, so put the fake first there.
    printf 'export PATH="%s/bin:$PATH"\n' "$T" > "$T/home/.bashrc"
    git -C "$T/repo" init -q .
    git -C "$T/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    cat > "$T/bin/claude" <<EOF
#!/bin/bash
n=\$(cat "$T/count" 2>/dev/null || echo 0); n=\$((n+1)); echo \$n > "$T/count"
echo "run \$n args: \$*" >> "$T/runs.log"
if [ "\$n" = 1 ]; then
    printf '{"session_id":"s-t4249","tokens":290000}' > "$T/repo/.context/working/.restart-requested"
else
    sleep 40   # run 2 stays alive: the wrapper must not read run 1's marker as run 2 exiting
fi
exit 0
EOF
    chmod +x "$T/bin/claude"
    cat > "$T/run.sh" <<EOF
#!/bin/bash
cd "$T/repo"
export HOME="$T/home" PATH="$T/bin:\$PATH" TMUX_TMPDIR="$T/tmx" TERMLINK_RUNTIME_DIR="$T/rt"
export FW_CLAUDE_FW_NO_REEXEC=1 FW_NO_TERMINATOR=1 FW_RESTART_MODE=fresh
unset TMUX TMUX_PANE TERMLINK_SESSION_ID
bash "$CFW" --termlink > "$T/out.log" 2>&1
echo "WRAPPER EXIT \$?" >> "$T/out.log"
EOF
    chmod +x "$T/run.sh"
}

teardown() {
    tmux -L "$SOCK" kill-server 2>/dev/null || true
    env -u TMUX TMUX_TMPDIR="$T/tmx" tmux kill-server 2>/dev/null || true   # the TermLink shell's private server
    TERMLINK_RUNTIME_DIR="$T/rt" termlink clean >/dev/null 2>&1 || true
    rm -rf "$T"
}

@test "T-4249: --termlink relaunches claude after it exits with a fresh restart signal" {
    env -u TMUX TMUX_TMPDIR="$T/tmx" tmux -L "$SOCK" -f /dev/null new-session -d -s t -x 200 -y 50 "$T/run.sh"
    for _ in $(seq 1 90); do
        [ "$(grep -c '^run ' "$T/runs.log" 2>/dev/null || echo 0)" -ge 2 ] && break
        grep -q "WRAPPER EXIT" "$T/out.log" 2>/dev/null && break
        sleep 1
    done
    sleep 12   # several 5 s polls: a stale marker would end the wrapper here
    cat "$T/out.log" >&2 || true
    if grep -q "WRAPPER EXIT" "$T/out.log"; then false; fi
    [ "$(grep -c '^run ' "$T/runs.log")" -ge 2 ]     # claude was relaunched
    grep -q "Auto-restart #1" "$T/out.log"           # and the restart is announced (T-4170)
    grep -q "Reason:" "$T/out.log"
}
