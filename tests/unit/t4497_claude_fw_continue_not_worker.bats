#!/usr/bin/env bats
# T-4497 — claude-fw's -c must continue the agent's conversation, never a worker's.
#
# `claude -c` continues the NEWEST conversation in the folder, and every `claude -p`
# worker (fw termlink dispatch) writes a newer one. 055 T-586, measured in 1409-sprind
# 2026-10-20: `claude-fw -c` was refused because the newest conversation was a live
# worker's; once a worker ends, -c resumes ITS transcript as if it were the agent. The
# T-179 auto-restart in FW_RESTART_MODE=continue relaunched with the same bare -c.
#
# A worker transcript records entrypoint "sdk-cli"; an interactive one "cli". All
# transcripts here are fakes under a temp HOME — ~/.claude is never touched.

export CLAUDE_FW_NO_SIDECAR=1

load ../test_helper

setup() {
    REPO="$FRAMEWORK_ROOT"
    TDIR="$(mktemp -d)"
    guard_project_root "$TDIR"
    TDIR="$(cd "$TDIR" && pwd -P)"
    mkdir -p "$TDIR/.context/working" "$TDIR/stubbin"
    : > "$TDIR/.framework.yaml"
    git -C "$TDIR" init -q
    export HOME="$TDIR"
    unset CLAUDE_CONFIG_DIR
    ENC=$(printf '%s' "$TDIR" | sed 's/[^A-Za-z0-9-]/-/g')
    CONV="$HOME/.claude/projects/$ENC"
    mkdir -p "$CONV"
    REC="$TDIR/.context/working/.claude-fw-conversation"
    source "$REPO/lib/conversation-holder.sh"
}

teardown() { rm -rf "$TDIR"; }

_conv() {   # _conv <id> <entrypoint> [age-seconds]
    printf '{"type":"summary"}\n{"type":"user","entrypoint":"%s","sessionId":"%s"}\n' "$2" "$1" > "$CONV/$1.jsonl"
    touch -d "-${3:-0} seconds" "$CONV/$1.jsonl"
}

@test "t4497: -c skips a NEWER sdk-cli worker conversation and targets the interactive one" {
    _conv agent cli 300; _conv worker sdk-cli 0
    run fw_conversation_target "$TDIR" -c
    [ "$output" = "agent" ]
}

@test "t4497: the recorded conversation wins over a newer interactive one" {
    _conv mine cli 300; _conv other cli 10; _conv worker sdk-cli 0
    echo mine > "$REC"
    run fw_conversation_continue_id "$TDIR" "$TDIR"
    [ "$output" = "mine" ]
}

@test "t4497: a recorded id that is a worker (or gone) is ignored" {
    _conv agent cli 300; _conv worker sdk-cli 0
    echo worker > "$REC"
    run fw_conversation_continue_id "$TDIR" "$TDIR"
    [ "$output" = "agent" ]
    echo vanished > "$REC"
    run fw_conversation_continue_id "$TDIR" "$TDIR"
    [ "$output" = "agent" ]
}

@test "t4497: -c becomes --resume <id>; with only workers it is dropped (fresh, never a worker)" {
    _conv agent cli 300; _conv worker sdk-cli 0
    run bash -c '. "$1"; fw_conversation_rewrite_continue "$2" "$2" --model x -c | tr "\0" " "' _ "$REPO/lib/conversation-holder.sh" "$TDIR"
    [ "$output" = "--model x --resume agent " ]
    rm "$CONV/agent.jsonl"
    run bash -c '. "$1"; fw_conversation_rewrite_continue "$2" "$2" --continue | tr "\0" " "' _ "$REPO/lib/conversation-holder.sh" "$TDIR"
    [ -z "$output" ]
}

@test "t4497: after a run the interactive conversation it wrote is recorded, not the worker's" {
    since=$(( $(date +%s) - 5 ))
    _conv old cli 600; _conv agent cli 0; _conv worker sdk-cli 0
    touch -d '+2 seconds' "$CONV/worker.jsonl"
    fw_conversation_record "$TDIR" "$TDIR" "$since" ""
    [ "$(cat "$REC")" = "agent" ]
    # A launched id this run wrote to is recorded even when another interactive one is newer.
    fw_conversation_record "$TDIR" "$TDIR" "$since" "old" ; [ "$(cat "$REC")" = "agent" ]
    touch "$CONV/old.jsonl"
    fw_conversation_record "$TDIR" "$TDIR" "$since" "old" ; [ "$(cat "$REC")" = "old" ]
}

# ── end to end, through the real wrapper ─────────────────────────────────────

_stub() {
    cat > "$TDIR/stubbin/claude" <<'STUB'
#!/bin/bash
root=$(git rev-parse --show-toplevel 2>/dev/null)
n=$(( $(cat "$root/.stub-runs" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$root/.stub-runs"
{ printf 'run=%s' "$n"; for a in "$@"; do printf '\t%s' "$a"; done; printf '\n'; } >> "$root/.stub-log"
if [ "$n" -eq 1 ] && [ "${STUB_RESTART:-0}" = 1 ]; then
    # This session writes its own conversation, then a worker writes a newer one.
    printf '{"type":"user","entrypoint":"cli"}\n' > "$STUB_CONV/own.jsonl"
    sleep 1
    printf '{"type":"user","entrypoint":"sdk-cli"}\n' > "$STUB_CONV/worker2.jsonl"
    printf '{"session_id":"s1","tokens":300000}\n' > "$root/.context/working/.restart-requested"
fi
exit 0
STUB
    chmod +x "$TDIR/stubbin/claude"
}

_wrapper() {
    cd "$TDIR" || return 1
    run env -u FRAMEWORK_ROOT PATH="$TDIR/stubbin:$PATH" HOME="$TDIR" PROJECT_ROOT="$TDIR" \
        STUB_CONV="$CONV" FW_NO_STARTUP_BANNER=1 FW_NO_TERMINATOR=1 FW_CLAUDE_FW_NO_TMUX=1 \
        FW_CLAUDE_FW_NO_REEXEC=1 FW_MAX_RESTARTS=3 FW_RESTART_WINDOW=3600 \
        timeout 120 bash "$REPO/bin/claude-fw" "$@"
}

@test "t4497 e2e: claude-fw -c hands claude --resume <interactive id>, never bare -c" {
    _stub
    _conv agent cli 300; _conv worker sdk-cli 0
    _wrapper --no-restart -c
    [ "$status" -eq 0 ]
    [ "$(cat "$TDIR/.stub-log")" = "$(printf 'run=1\t--resume\tagent')" ]
    [ "$(cat "$REC")" = "agent" ]
}

@test "t4497 e2e: FW_RESTART_MODE=continue relaunch resumes this session's conversation, not the newer worker's" {
    _stub
    _conv older cli 300
    STUB_RESTART=1 FW_RESTART_MODE=continue _wrapper
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$TDIR/.stub-log")" -eq 2 ]
    [ "$(sed -n 2p "$TDIR/.stub-log")" = "$(printf 'run=2\t--resume\town')" ]
    ! grep -qP '\t-c(\t|$)' "$TDIR/.stub-log" || false
}

@test "t4497: no literal CLAUDE_ARGS=(\"-c\") reaches claude without passing the resolver" {
    # Both continue-mode relaunches still set -c; the loop resolves it before every launch.
    awk '/^while true; do/{w=1} w && /_resolve_continue/{print; exit}' "$REPO/bin/claude-fw" | grep -q _resolve_continue
    awk '/^while true; do/{w=1} w' "$REPO/bin/claude-fw" | grep -n '_resolve_continue\|_conversation_guard ||' | head -2 | sed -n 1p | grep -q _resolve_continue
}
