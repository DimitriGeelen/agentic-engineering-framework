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
    # T-4682: unique per run, so a leaked session can never make the next run fail 'duplicate'.
    N="t4217-w-${D##*.}"
    mkdir -p "$D/bin" "$D/dispatch" "$D/tmx" "$D/rt"
    # T-4647: the socket is baked into the stub — spawn now runs under an allow-listed env, so an
    # exported test variable would not reach it. T-4682: the stub is injected via TERMLINK_BIN, not
    # PATH (T-4666 builds the spawn PATH by construction, and claude's dir — which holds the real
    # termlink — comes before a caller-prepended dir), and it leaves a marker so the test can prove
    # the stub, not the real binary, was the one that ran.
    printf '#!/bin/bash\necho "$*" > %q\nexec tmux -S %q new-session -d -s w "sleep 60"\n' \
        "$D/stub.ran" "$SOCK" > "$D/bin/termlink"
    chmod +x "$D/bin/termlink"
}

teardown() {
    # The server on $SOCK goes first; the directory only after it is gone.
    [ -n "${D:-}" ] && [ -S "$SOCK" ] && tmux -S "$SOCK" kill-server 2>/dev/null
    # Belt and braces (T-4682): should a real termlink ever run, TMUX_TMPDIR kept its server under
    # $D — kill it there — and if the session still reached the real hub, remove it by name.
    local s
    for s in "${D:-/nonexistent}"/tmx/tmux-*/*; do [ -S "$s" ] && tmux -S "$s" kill-server 2>/dev/null; done
    if [ -n "${N:-}" ] && command -v termlink >/dev/null 2>&1 && termlink list 2>/dev/null | grep -qw -- "$N"; then
        echo "T-4682: session $N reached the real TermLink hub; removing it" >&2
        termlink signal "$N" SIGTERM 2>/dev/null; termlink clean 2>/dev/null
    fi
    [ -n "${D:-}" ] && rm -rf "$D"
    return 0
}

@test "T-4217: a spawn's private tmux server gets none of the six fw path variables (T-4222: + TASKS_DIR, CONTEXT_DIR) in its global env" {
    run env -u TMUX -u TMUX_PANE PATH="$D/bin:$PATH" TERMLINK_BIN="$D/bin/termlink" \
        TMUX_TMPDIR="$D/tmx" TERMLINK_RUNTIME_DIR="$D/rt" \
        PROJECT_ROOT=/some/other/project FRAMEWORK_ROOT=/some/other/project/.agentic-framework \
        _FW_PATHS_DERIVED_BY=test FW_ROUTED_FROM=/some/other/project \
        TASKS_DIR=/some/other/project/.tasks CONTEXT_DIR=/some/other/project/.context \
        FW_DISPATCH_DIR="$D/dispatch" \
        bash "$ROOT/agents/termlink/termlink.sh" spawn --name "$N" --task T-4217
    [ "$status" -eq 0 ]
    # Loud, not silent: a spawn that ran some other termlink must fail here, by name.
    [ -s "$D/stub.ran" ] || { echo "T-4682: the stub termlink did not run — spawn used another binary"; false; }
    grep -q -- "^spawn --name $N " "$D/stub.ran"
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
# T-4686: every fact _cfw_should_wrap_tmux (bin/claude-fw) reads is set here, never inherited:
# env -i drops FW_CLAUDE_FW_NO_TMUX / FW_CLAUDE_FW_IN_TMUX / FW_DISPATCHED_WORKER / TL_CLAUDE_ENABLED
# / TMUX / FW_CFW_REEXEC_PID; no --termlink, no -p; script(1) gives the pty; PATH is built, with the
# stubs first and no host dir that could hold a real tmux or claude ahead of them; SHELL is bash
# (script runs "$SHELL -c", and a zsh /etc/zshenv may rebuild PATH); FW_AGENT_SCOPE=0 skips the
# systemd-run re-exec, whose probe alone may take as long as the 10 s timeout on another host.
# A stub claude means a skipped wrap never starts a real session. The stub tmux records its
# argv, so the test proves the WRAP ran rather than some other tmux call made later.
@test "T-4217: claude-fw's tmux wrap does not hand the caller's path variables to the server" {
    command -v script >/dev/null || skip "script(1) unavailable (needed for a pty)"
    W="$(mktemp -d /tmp/t4217w.XXXXXX)"
    mkdir -p "$W/bin" "$W/home"
    printf '#!/bin/bash\necho "$*" > %q\nenv > %q\nexit 0\n' "$W/tmux.args" "$W/tmux.env" > "$W/bin/tmux"
    printf '#!/bin/bash\necho "$*" > %q\nexit 0\n' "$W/claude.ran" > "$W/bin/claude"
    chmod +x "$W/bin/tmux" "$W/bin/claude"
    run env -i PATH="$W/bin:/usr/bin:/bin" HOME="$W/home" SHELL=/bin/bash TERM=xterm LANG=C.UTF-8 \
        FW_AGENT_SCOPE=0 \
        PROJECT_ROOT=/some/other/project FRAMEWORK_ROOT=/some/other/project/.agentic-framework \
        _FW_PATHS_DERIVED_BY=test FW_ROUTED_FROM=/some/other/project \
        TASKS_DIR=/some/other/project/.tasks CONTEXT_DIR=/some/other/project/.context \
        script -qec "cd '$W' && timeout 10 bash '$ROOT/bin/claude-fw' -c" /dev/null
    if [ ! -s "$W/tmux.args" ]; then
        echo "T-4686: fake tmux never ran — claude-fw did not take the tmux wrap (claude stub ran: $([ -e "$W/claude.ran" ] && echo yes || echo no))"
        echo "$output"; rm -rf "$W"; false
    fi
    if ! grep -q -- '^-L fw-agents -f /dev/null new-session ' "$W/tmux.args"; then
        echo "T-4686: fake tmux ran, but not as the wrap:"; cat "$W/tmux.args"; rm -rf "$W"; false
    fi
    if grep -qE '^(PROJECT_ROOT|FRAMEWORK_ROOT|_FW_PATHS_DERIVED_BY|FW_ROUTED_FROM|TASKS_DIR|CONTEXT_DIR)=' "$W/tmux.env"; then
        echo "leaked into the tmux server's env:"; cat "$W/tmux.env"; rm -rf "$W"; false
    fi
    rm -rf "$W"
}

# T-4682: the binary the spawn runs is the one the caller resolved. Since T-4666 the spawn PATH is
# constructed with claude's dir (which holds the real termlink) ahead of a caller-prepended dir, so
# a bare `termlink` there bypassed PATH stubs and spawned REAL sessions on the default tmux server.
@test "T-4682: cmd_spawn runs the caller's resolved termlink by absolute path (TERMLINK_BIN wins)" {
    grep -qF 'local tl_bin="${TERMLINK_BIN:-$(command -v termlink)}"' "$ROOT/agents/termlink/termlink.sh"
    grep -qF '"$tl_bin" spawn "${spawn_args[@]}"' "$ROOT/agents/termlink/termlink.sh"
    run env -i PATH=/usr/bin:/bin HOME=/root TERMLINK_BIN=/b/termlink \
        bash -c '. "$1"; fw_spawn_env; printf "%s\n" "${FW_SPAWN_ENV[@]}"' _ "$ROOT/lib/spawn-env.sh"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qx 'TERMLINK_BIN=/b/termlink'
}

@test "T-4682: a stub termlink first on the caller's PATH (no TERMLINK_BIN) is the one spawn runs" {
    run env -u TMUX -u TMUX_PANE -u TERMLINK_BIN PATH="$D/bin:$PATH" \
        TMUX_TMPDIR="$D/tmx" TERMLINK_RUNTIME_DIR="$D/rt" FW_DISPATCH_DIR="$D/dispatch" \
        bash "$ROOT/agents/termlink/termlink.sh" spawn --name "$N" --task T-4217
    [ "$status" -eq 0 ]
    [ -s "$D/stub.ran" ] || { echo "T-4682: the PATH stub did not run — spawn used another binary"; false; }
    grep -q -- "^spawn --name $N " "$D/stub.ran"
}
