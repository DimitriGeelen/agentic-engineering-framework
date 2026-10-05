#!/usr/bin/env bats
# T-3890: claude-fw must not open a conversation another live process holds.
# 832 (2026-10-05): a fleet resume-by-id plus a separate `claude-fw -c` ran the
# same conversation twice for ~2h45; both executed one runme step.
# A fake holder is a process whose argv[0] is "claude" (exec -a).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FWROOT="${BATS_TEST_DIRNAME}/../.."
    source "$FWROOT/lib/conversation-holder.sh"
    export CLAUDE_CONFIG_DIR="$TEST_TEMP_DIR/cfg"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/sidecar/sessions"
    ENC=$(printf '%s' "$PROJ" | sed 's/[^A-Za-z0-9-]/-/g')
    mkdir -p "$CLAUDE_CONFIG_DIR/projects/$ENC"
    HOLDER=""
}

teardown() {
    [ -n "$HOLDER" ] && kill "$HOLDER" 2>/dev/null || true
    rm -rf "$TEST_TEMP_DIR"
}

_conv() {   # _conv <id> [age-seconds]
    touch -d "-${2:-0} seconds" "$CLAUDE_CONFIG_DIR/projects/$ENC/$1.jsonl"
}
_record() { printf '{"session_id":"%s","claude_pid":%s}\n' "$1" "$2" > "$PROJ/.context/sidecar/sessions/$1.json"; }
_live_claude() { bash -c 'exec -a claude sleep 60' & HOLDER=$!; sleep 0.2; }

@test "t3890: -c targets the NEWEST conversation in this directory" {
    _conv old 100; _conv new 0
    run fw_conversation_target "$PROJ" -c
    [ "$output" = "new" ]
}

@test "t3890: --resume <id> and --resume=<id> target that id; no flag targets nothing" {
    run fw_conversation_target "$PROJ" --resume abc
    [ "$output" = "abc" ]
    run fw_conversation_target "$PROJ" --resume=xyz
    [ "$output" = "xyz" ]
    run fw_conversation_target "$PROJ" -n fresh
    [ -z "$output" ]
}

@test "t3890: a live claude holding the conversation is reported" {
    _conv c1; _live_claude; _record c1 "$HOLDER"
    run fw_conversation_holder "$PROJ" c1
    [ "$output" = "$HOLDER" ]
}

@test "t3890: holder exited (auto-restart's own -c) → no holder" {
    _conv c1; _live_claude; _record c1 "$HOLDER"
    kill "$HOLDER"; wait "$HOLDER" 2>/dev/null || true
    run fw_conversation_holder "$PROJ" c1
    [ -z "$output" ]
}

@test "t3890: a live pid that is NOT claude (recycled pid) is not a holder" {
    _conv c1; sleep 60 & HOLDER=$!; _record c1 "$HOLDER"
    run fw_conversation_holder "$PROJ" c1
    [ -z "$output" ]
}

@test "t3890: claude-fw refuses before launching, and the override is honoured" {
    f="$FWROOT/bin/claude-fw"
    g=$(grep -n '_conversation_guard || exit 3' "$f" | cut -d: -f1)
    l=$(grep -n 'command claude "\${CLAUDE_ARGS\[@\]}"' "$f" | cut -d: -f1)
    t=$(grep -n 'termlink_inject "claude\${_tl_args}' "$f" | cut -d: -f1)
    [ -n "$g" ] && [ "$g" -lt "$l" ] && [ "$g" -lt "$t" ]
    # the guard function itself: refuse, then override
    eval "$(awk '/^_conversation_guard\(\) \{/{p=1} p{print} p&&/^\}/{exit}' "$f")"
    _conv c1; _live_claude; _record c1 "$HOLDER"
    cd "$PROJ"; export PROJECT_ROOT="$PROJ"
    CLAUDE_ARGS=(-c)
    # the guard locates the lib next to bin/claude-fw via BASH_SOURCE; point it there
    readlink() { [ "$1" = "-f" ] && echo "$f" || command readlink "$@"; }
    run _conversation_guard
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFUSED — conversation c1 is already live in pid $HOLDER"* ]]
    FW_ALLOW_DUPLICATE_CONVERSATION=1 run _conversation_guard
    [ "$status" -eq 0 ]
    [[ "$output" == *"continuing anyway"* ]]
}
