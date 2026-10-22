#!/usr/bin/env bats
# T-4651 (close test for G-116 / G-124, T-4635 RCA) — A-after-B on a polluted tmux server.
#
# "Project B" starts a tmux server first, carrying B's PROJECT_ROOT/FRAMEWORK_ROOT/CONTEXT_DIR/
# TASKS_DIR/FW_* in the server's global environment (both from the starting process env and
# via `set-environment -g`). Every later session on that server inherits it. "Project A" then
# launches a child through each AEF path, and the child must carry none of B's paths and must
# resolve A's own .tasks/.context.
#
# Paths under test, and how each is pointed at the private server:
#   dispatch  — the launcher env is built by lib/spawn-env.sh (fw_spawn_env) exactly as
#               cmd_spawn uses it, and the session runs the run.sh runtime taken verbatim from
#               agents/termlink/termlink.sh's RUNEOF heredoc (up to the end of its path setup,
#               before any ledger/worker launch), plus a probe. `termlink spawn` itself has no
#               socket option and registers with the live hub, so it is not invoked.
#   claude-fw — the line claude-fw injects into the TermLink PTY shell, rendered from
#               bin/claude-fw's own source (as t4638 does), run as a session on the server with
#               a stand-in `claude` that records what it sees. TermLink itself is not invoked.
#               B's FW_* are dropped too (T-4659); FW_* from claude-fw's own env still arrive.
#
# Only a PRIVATE server is used (tmux -L t4651-$$-<rand>, socket dir inside the test tmpdir),
# killed in teardown. The default tmux server is never touched. Every tmux call has a timeout.
#
# T4651_REPO=<dir> runs the same assertions against another tree (a `git archive` scratch copy
# of older code) — that is how the red-before evidence in the task was produced.

export CLAUDE_FW_NO_SIDECAR=1

setup() {
    REPO="${T4651_REPO:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    T="$(mktemp -d)"; T="$(cd "$T" && pwd -P)"
    A="$T/projA"; B="$T/projB"
    for p in "$A" "$B"; do
        mkdir -p "$p/.tasks/active" "$p/.context/working"
        : > "$p/.framework.yaml"
    done
    # A is a consumer whose vendored framework is the tree under test.
    ln -s "$REPO" "$A/.agentic-framework"
    mkdir -p "$T/bin" "$T/home" "$T/tmx"
    SOCK="t4651-$$-$RANDOM$RANDOM"
    unset TMUX TMUX_PANE
    export TMUX_TMPDIR="$T/tmx"
    BASE_ENV=(PATH="$T/bin:/usr/bin:/bin" HOME="$T/home" SHELL=/bin/bash TERM=xterm TMUX_TMPDIR="$T/tmx")
    B_ENV=(PROJECT_ROOT="$B" FRAMEWORK_ROOT="$B" CONTEXT_DIR="$B/.context" TASKS_DIR="$B/.tasks"
           _FW_PATHS_DERIVED_BY="$B" FW_FOO="$B")
    # Project B starts the server, with its paths in the starting env...
    env -i "${BASE_ENV[@]}" "${B_ENV[@]}" \
        timeout 10 tmux -L "$SOCK" -f /dev/null new-session -d -s b -c "$B" 'sleep 600'
    # ...and in the global environment explicitly.
    local kv
    for kv in "${B_ENV[@]}"; do
        _tmx set-environment -g "${kv%%=*}" "${kv#*=}"
    done
}

teardown() {
    timeout 10 tmux -L "$SOCK" -f /dev/null kill-server 2>/dev/null || true
    rm -rf "$T"
}

_tmx() { timeout 10 tmux -L "$SOCK" -f /dev/null "$@"; }

_wait_for() {   # _wait_for <file> — up to 15 s
    local i
    for i in $(seq 1 75); do [ -e "$1" ] && return 0; sleep 0.2; done
    echo "timed out waiting for $1" >&2
    return 1
}

# No line of an env dump may carry B's path.
_assert_no_b() {   # _assert_no_b <env-dump>
    if grep -F "$B" "$1"; then
        echo "FOREIGN (project B) value reached project A's child (above)" >&2
        return 1
    fi
}

# paths.sh resolution, run in the child, must land on A.
_assert_resolves_a() {   # _assert_resolves_a <paths-out>
    cat "$1"
    grep -qx "TASKS_DIR=$A/.tasks" "$1"
    grep -qx "CONTEXT_DIR=$A/.context" "$1"
}

_probe() {   # the shell lines a child runs to record what it sees; $1 = output dir
    cat <<EOF
env > "$1/env.out"
( unset _FW_PATHS_LOADED; source "$REPO/lib/paths.sh" 2>"$1/paths.err"
  printf 'TASKS_DIR=%s\nCONTEXT_DIR=%s\n' "\$TASKS_DIR" "\$CONTEXT_DIR" ) > "$1/paths.out"
touch "$1/done"
EOF
}

@test "T-4651 control: a plain session A starts on B's server carries B's paths (the server is polluted)" {
    mkdir -p "$T/c"
    _probe "$T/c" > "$T/c/probe.sh"
    env -i "${BASE_ENV[@]}" PROJECT_ROOT="$A" \
        timeout 10 tmux -L "$SOCK" -f /dev/null new-session -d -s ctl -c "$A" "bash $T/c/probe.sh"
    _wait_for "$T/c/done"
    grep -qx "CONTEXT_DIR=$B/.context" "$T/c/env.out"
    grep -qx "TASKS_DIR=$B/.tasks" "$T/c/env.out"
    grep -qx "FW_FOO=$B" "$T/c/env.out"
}

# The launcher env A's fw builds for the spawn, when A's fw itself runs in a pane of B's server
# (its own env carries B's leftovers). Without lib/spawn-env.sh (pre-T-4647 code) the launcher
# is the minimal env, so the run.sh leg below still measures the runtime on its own.
_launcher_env() {   # sets LAUNCH_ENV
    LAUNCH_ENV=("${BASE_ENV[@]}")
    [ -f "$REPO/lib/spawn-env.sh" ] || return 0
    local FW_SPAWN_ENV=()
    eval "$(
        export "${BASE_ENV[@]}" "${B_ENV[@]}"
        export PROJECT_ROOT="$A" FRAMEWORK_ROOT="$A/.agentic-framework"
        # shellcheck source=/dev/null
        source "$REPO/lib/spawn-env.sh"
        fw_spawn_env
        declare -p FW_SPAWN_ENV
    )"
    LAUNCH_ENV=("${FW_SPAWN_ENV[@]}")
}

@test "T-4651 dispatch builder: fw_spawn_env drops B's paths from a polluted caller env" {
    [ -f "$REPO/lib/spawn-env.sh" ] || { echo "no lib/spawn-env.sh in $REPO" >&2; false; }
    _launcher_env
    printf '%s\n' "${LAUNCH_ENV[@]}" > "$T/launcher.env"
    cat "$T/launcher.env"
    grep -q '^PATH=' "$T/launcher.env"
    _assert_no_b "$T/launcher.env"
}

@test "T-4651 dispatch runtime: run.sh launched by A on B's server — no B path, A's dirs resolve" {
    W="$T/w"; mkdir -p "$W"
    # run.sh exactly as cmd_dispatch writes it, cut after its project path setup.
    sed -n "/^    cat > \"\$wdir\/run.sh\" <<'RUNEOF'\$/,/^RUNEOF\$/p" "$REPO/agents/termlink/termlink.sh" \
        | sed '1d;$d' | sed '/^# T-3580 round 5: evidence that THIS runtime/,$d' > "$W/run.sh"
    grep -q 'export FRAMEWORK_ROOT=' "$W/run.sh"
    _probe "$W" >> "$W/run.sh"
    _launcher_env
    env -i "${LAUNCH_ENV[@]}" timeout 10 tmux -L "$SOCK" -f /dev/null \
        new-session -d -s a -c "$A" "bash $W/run.sh w4651 $A $W 60 none build fw"
    _wait_for "$W/done"
    _assert_no_b "$W/env.out"
    grep -qx "PROJECT_ROOT=$A" "$W/env.out"
    _assert_resolves_a "$W/paths.out"
}

# Run the claude-fw PTY line on B's server; $1 = output dir, $2.. = NAME=VALUE exported in the
# claude-fw process that renders the line (its own launch env).
_run_claude_fw_line() {
    local P="$1"; shift
    mkdir -p "$P"
    INJECT_SRC=$(grep -E '^[[:space:]]*termlink_inject "[^"]*command claude\$\{_tl_args\}' "$REPO/bin/claude-fw")
    [ -n "$INJECT_SRC" ]
    PIN_SRC=$(grep -E '^[[:space:]]*_tl_pin=\$\(_tl_project_env_prefix\)' "$REPO/bin/claude-fw" || true)
    HELPERS=$(sed -n '/^_tl_sidecar_env_prefix() {/,/^}/p; /^_tl_project_env_prefix() {/,/^}/p' "$REPO/bin/claude-fw")
    # Stand-in claude: records the environment it was launched with.
    { echo '#!/bin/bash'; _probe "$P"; } > "$T/bin/claude"
    chmod +x "$T/bin/claude"
    # Render the injected line as claude-fw builds it with project A pinned.
    line=$(
        local kv; for kv in "$@"; do export "$kv"; done
        CLAUDE_ARGS=(); restart_count=0; _tl_args=""; _tl_env=""; _tl_pin=""
        PROJECT_ROOT="$A"; FRAMEWORK_ROOT="$A/.agentic-framework"
        unset TERMLINK_SIDECAR_SOCKET TERMLINK_SIDECAR_STATUS_SOCKET
        eval "$HELPERS"
        eval "$PIN_SRC"
        _tl_tok="r0p1e1"
        termlink_inject() { printf '%s\n' "$1"; }
        eval "$INJECT_SRC"
    )
    printf '%s\n' "$line" > "$P/pty.sh"
    env -i "${BASE_ENV[@]}" timeout 10 tmux -L "$SOCK" -f /dev/null \
        new-session -d -s a -c "$A" "bash --noprofile --norc $P/pty.sh 2>$P/pty.err"
    _wait_for "$P/done"
}

@test "T-4651 claude-fw: the injected PTY line on B's server launches claude with no B path or FW_*, A's dirs resolve" {
    P="$T/p"
    _run_claude_fw_line "$P"
    _assert_no_b "$P/env.out"
    ! grep -q '^FW_FOO=' "$P/env.out" || false
    grep -qx "PROJECT_ROOT=$A" "$P/env.out"
    _assert_resolves_a "$P/paths.out"
}

@test "T-4659 claude-fw: an FW_* set in claude-fw's own launch env still reaches claude, B's FW_FOO does not" {
    P="$T/q"
    _run_claude_fw_line "$P" FW_TERMLINK_MAX_WORKERS=7 "FW_SAFE_MODE=has space"
    grep -qx "FW_TERMLINK_MAX_WORKERS=7" "$P/env.out"
    grep -qx "FW_SAFE_MODE=has space" "$P/env.out"
    ! grep -q '^FW_FOO=' "$P/env.out" || false
    _assert_no_b "$P/env.out"
}
