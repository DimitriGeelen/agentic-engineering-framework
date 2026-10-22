#!/usr/bin/env bats
# T-4638 (T-4635 RCA) — after a relaunch the AEF session ran with 1409-sprind's CONTEXT_DIR /
# TASKS_DIR: in --termlink mode claude is typed into the TermLink PTY shell, whose environment
# comes from the shared tmux server another project's spawn had started. claude-fw now pins
# that shell to its own project in the injected line, saying so once; plain mode warns too.
#
# The injected line and its helpers are taken from bin/claude-fw's own source (as T-4474 does)
# and run in an `env -i` interactive bash carrying a FAKE foreign environment, with a stand-in
# claude that records what it sees. No real project, tmux or TermLink is touched.

export CLAUDE_FW_NO_SIDECAR=1

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"; T="$(cd "$T" && pwd -P)"
    mkdir -p "$T/bin" "$T/own/.context/working" "$T/foreign/.tasks" "$T/foreign/.context"
    : > "$T/own/.framework.yaml"; : > "$T/foreign/.framework.yaml"
    cat > "$T/bin/claude" <<EOF
#!/bin/bash
for v in PROJECT_ROOT FRAMEWORK_ROOT TASKS_DIR CONTEXT_DIR _FW_PATHS_DERIVED_BY; do
    printf '%s=%s\n' "\$v" "\${!v-<unset>}"
done >> "$T/seen"
exit 0
EOF
    chmod +x "$T/bin/claude"
    INJECT_SRC=$(grep -E '^[[:space:]]*termlink_inject "[^"]*command claude\$\{_tl_args\}' "$REPO/bin/claude-fw")
    PIN_SRC=$(grep -E '^[[:space:]]*_tl_pin=\$\(_tl_project_env_prefix\)' "$REPO/bin/claude-fw")
    HELPERS=$(sed -n '/^_tl_sidecar_env_prefix() {/,/^}/p; /^_tl_project_env_prefix() {/,/^}/p' "$REPO/bin/claude-fw")
    [ -n "$INJECT_SRC" ] && [ -n "$PIN_SRC" ]
}

teardown() { rm -rf "$T"; }

# The injected text, rendered as claude-fw builds it with this project pinned.
_injected_line() {
    local CLAUDE_ARGS=() restart_count=0 _tl_args="" _tl_env="" _tl_pin="" _tl_tok
    PROJECT_ROOT="$T/own"; FRAMEWORK_ROOT="$T/own/.agentic-framework"
    unset TERMLINK_SIDECAR_SOCKET TERMLINK_SIDECAR_STATUS_SOCKET
    eval "$HELPERS"
    eval "$PIN_SRC"
    _tl_tok="r0p1e1"
    termlink_inject() { printf '%s\n' "$1"; }
    eval "$INJECT_SRC"
}

# An interactive shell like the TermLink PTY, started with the given (foreign) environment.
_pty_shell() {   # _pty_shell <script> [VAR=value ...]
    local script="$1"; shift
    printf '%s\nexit\n' "$script" | env -i HOME="$T" PATH="$T/bin:/usr/bin:/bin" "$@" bash --norc -i 2>"$T/err" >"$T/out"
}

@test "T-4638: a PTY shell carrying another project's paths launches claude on this project's paths" {
    line=$(_injected_line)
    _pty_shell "$line" PROJECT_ROOT="$T/foreign" TASKS_DIR="$T/foreign/.tasks" \
        CONTEXT_DIR="$T/foreign/.context" _FW_PATHS_DERIVED_BY=x
    cat "$T/seen" "$T/err"
    grep -qx "PROJECT_ROOT=$T/own" "$T/seen"
    grep -qx "FRAMEWORK_ROOT=$T/own/.agentic-framework" "$T/seen"
    grep -qx "TASKS_DIR=<unset>" "$T/seen"
    grep -qx "CONTEXT_DIR=<unset>" "$T/seen"
    grep -qx "_FW_PATHS_DERIVED_BY=<unset>" "$T/seen"
    grep -q '__CLAUDE_FW_EXIT_r0p1e1_0__' "$T/out"      # the exit marker still reports claude's status
}

@test "T-4638: it says so once — one line per foreign value, nothing on the next relaunch" {
    line=$(_injected_line)
    _pty_shell "$line"$'\n'"$line" PROJECT_ROOT="$T/foreign" TASKS_DIR="$T/foreign/.tasks" CONTEXT_DIR="$T/foreign/.context"
    cat "$T/err"
    [ "$(grep -c 'claude-fw: inherited .* is not this project; cleared for' "$T/err")" -eq 3 ]
    grep -q "inherited TASKS_DIR=$T/foreign/.tasks is not this project" "$T/err"
    [ "$(grep -c "^PROJECT_ROOT=$T/own$" "$T/seen")" -eq 2 ]    # both launches pinned
}

@test "T-4638/control: a clean shell, or one already on this project, prints nothing" {
    line=$(_injected_line)
    _pty_shell "$line"
    ! grep -q 'claude-fw: inherited' "$T/err" || false
    _pty_shell "$line" PROJECT_ROOT="$T/own" TASKS_DIR="$T/own/.tasks"
    ! grep -q 'claude-fw: inherited' "$T/err" || false
    grep -qx "TASKS_DIR=<unset>" "$T/seen"
}

@test "T-4638/control: outside any project (PROJECT_ROOT empty) the line gains nothing" {
    PROJECT_ROOT="" run bash -c "$HELPERS"$'\n''_tl_project_env_prefix'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-4638: plain mode warns for a foreign TASKS_DIR/CONTEXT_DIR and claude does not see them" {
    run env -u TMUX -u FW_DISPATCHED_WORKER -u TL_CLAUDE_ENABLED -u PROJECT_ROOT -u FRAMEWORK_ROOT \
        PATH="$T/bin:$PATH" HOME="$T" FW_AGENT_SCOPE=0 FW_CLAUDE_FW_NO_TMUX=1 \
        TASKS_DIR="$T/foreign/.tasks" CONTEXT_DIR="$T/foreign/.context" \
        bash -c "cd '$T/own' && timeout 30 bash '$REPO/bin/claude-fw' --no-restart -p hello < /dev/null"
    echo "$output"; cat "$T/seen"
    echo "$output" | grep -q "inherited TASKS_DIR=$T/foreign/.tasks is not this project; cleared for $T/own (T-4638)"
    echo "$output" | grep -q "inherited CONTEXT_DIR=$T/foreign/.context is not this project"
    grep -qx "TASKS_DIR=<unset>" "$T/seen"
    grep -qx "CONTEXT_DIR=<unset>" "$T/seen"
    grep -qx "PROJECT_ROOT=$T/own" "$T/seen"
}
