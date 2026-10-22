#!/usr/bin/env bats
# T-4217 — `fw termlink dispatch` spawned workers with fw's full environment. A `termlink spawn`
# that finds no tmux server starts one, and that server's GLOBAL environment is whatever the
# spawning process carried: PROJECT_ROOT / FRAMEWORK_ROOT / _FW_PATHS_DERIVED_BY / FW_ROUTED_FROM.
# Every agent later started on that server then inherited another project's paths (G-116).
# Real tmux on a PRIVATE socket (-S). The fake termlink stands in for `termlink spawn`: it starts
# the server exactly the way the real one does (tmux new-session -d), using the env it was given.
# Never the host's default socket: every tmux call here names $SOCK.

setup() {
    ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    command -v tmux >/dev/null 2>&1 || skip "tmux not installed"
    # Short path: a unix socket path is capped at ~108 bytes.
    D="$(mktemp -d /tmp/t4217.XXXXXX)"
    SOCK="$D/sock"
    mkdir -p "$D/bin" "$D/dispatch"
    # T-4647: the socket is baked into the stub — spawn now runs under an allow-listed env, so an
    # exported test variable would not reach it.
    printf '#!/bin/bash\nexec tmux -S %q new-session -d -s w "sleep 60"\n' "$SOCK" > "$D/bin/termlink"
    chmod +x "$D/bin/termlink"
}

teardown() {
    # The server on $SOCK goes first; the directory only after it is gone.
    [ -n "${D:-}" ] && [ -S "$SOCK" ] && tmux -S "$SOCK" kill-server 2>/dev/null
    [ -n "${D:-}" ] && rm -rf "$D"
}

@test "T-4217: a spawn's private tmux server gets none of the six fw path variables (T-4222: + TASKS_DIR, CONTEXT_DIR) in its global env" {
    run env PATH="$D/bin:$PATH" \
        PROJECT_ROOT=/some/other/project FRAMEWORK_ROOT=/some/other/project/.agentic-framework \
        _FW_PATHS_DERIVED_BY=test FW_ROUTED_FROM=/some/other/project \
        TASKS_DIR=/some/other/project/.tasks CONTEXT_DIR=/some/other/project/.context \
        FW_DISPATCH_DIR="$D/dispatch" \
        bash "$ROOT/agents/termlink/termlink.sh" spawn --name t4217-w --task T-4217
    [ "$status" -eq 0 ]
    [ -S "$SOCK" ]
    run tmux -S "$SOCK" show-environment -g
    [ "$status" -eq 0 ]
    if echo "$output" | grep -qE '^(PROJECT_ROOT|FRAMEWORK_ROOT|_FW_PATHS_DERIVED_BY|FW_ROUTED_FROM|TASKS_DIR|CONTEXT_DIR)='; then
        echo "leaked into tmux global env:"; echo "$output"; false
    fi
}

# The claude-fw tmux wrap starts its own server (-L fw-agents). A server takes its global env from
# the process that starts it, so the wrap's tmux call must not carry the caller's path variables;
# the session still gets them through -e. A fake tmux records the environment it was started with.
@test "T-4217: claude-fw's tmux wrap does not hand the caller's path variables to the server" {
    command -v script >/dev/null || skip "script(1) unavailable (needed for a pty)"
    W="$(mktemp -d /tmp/t4217w.XXXXXX)"
    mkdir -p "$W/bin"
    printf '#!/bin/bash\nenv > %q\nexit 0\n' "$W/tmux.env" > "$W/bin/tmux"
    chmod +x "$W/bin/tmux"
    run env -u TMUX -u FW_CLAUDE_FW_IN_TMUX -u FW_DISPATCHED_WORKER -u TL_CLAUDE_ENABLED \
        PATH="$W/bin:$PATH" PROJECT_ROOT=/some/other/project FRAMEWORK_ROOT=/some/other/project/.agentic-framework \
        _FW_PATHS_DERIVED_BY=test FW_ROUTED_FROM=/some/other/project \
        TASKS_DIR=/some/other/project/.tasks CONTEXT_DIR=/some/other/project/.context \
        script -qec "cd '$W' && timeout 10 bash '$ROOT/bin/claude-fw' -c" /dev/null
    [ -s "$W/tmux.env" ]
    if grep -qE '^(PROJECT_ROOT|FRAMEWORK_ROOT|_FW_PATHS_DERIVED_BY|FW_ROUTED_FROM|TASKS_DIR|CONTEXT_DIR)=' "$W/tmux.env"; then
        rm -rf "$W"; false
    fi
    rm -rf "$W"
}
