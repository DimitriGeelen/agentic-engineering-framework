#!/usr/bin/env bats
# T-3779: TERMLINK_RUNTIME_DIR split-brain. A launcher running an agent under
# `env -i` drops the variable; `termlink register` then lands in
# /tmp/termlink-$UID where no hub listens (2026-10-05: 27 fleet sessions,
# AEF's included). Fake hubs here are a real AF_UNIX socket plus a pidfile
# naming a live ($$) or impossible pid.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    FWROOT="${BATS_TEST_DIRNAME}/../.."
    source "$FWROOT/lib/termlink-runtime.sh"
    unset TERMLINK_RUNTIME_DIR TERMLINK_SESSION_ID
    export FW_TERMLINK_DEFAULT_RUNTIME_DIR="$TEST_TEMP_DIR/default"
    export TERMLINK_RUNTIME_DIR_FALLBACK="$TEST_TEMP_DIR/canon"
    mkdir -p "$TEST_TEMP_DIR/default/sessions" "$TEST_TEMP_DIR/canon/sessions"
}

_hub() {   # _hub <dir> live|dead
    python3 -c "import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])" "$1/hub.sock"
    if [ "$2" = live ]; then echo $$ > "$1/hub.pid"; else echo 2147483646 > "$1/hub.pid"; fi
}

@test "t3779: hub_live needs a socket AND a live pid" {
    run fw_termlink_hub_live "$TEST_TEMP_DIR/canon"; [ "$status" -ne 0 ]
    _hub "$TEST_TEMP_DIR/canon" dead
    run fw_termlink_hub_live "$TEST_TEMP_DIR/canon"; [ "$status" -ne 0 ]
    echo $$ > "$TEST_TEMP_DIR/canon/hub.pid"
    run fw_termlink_hub_live "$TEST_TEMP_DIR/canon"; [ "$status" -eq 0 ]
}

@test "t3779: an explicit TERMLINK_RUNTIME_DIR is never overridden" {
    _hub "$TEST_TEMP_DIR/canon" live
    TERMLINK_RUNTIME_DIR=/somewhere/else run fw_termlink_runtime_resolve
    [[ "$output" == "set /somewhere/else "* ]]
}

@test "t3779: unset + live hub in the default dir → default (nothing to do)" {
    _hub "$TEST_TEMP_DIR/default" live
    _hub "$TEST_TEMP_DIR/canon" live
    run fw_termlink_runtime_resolve
    [[ "$output" == "default $TEST_TEMP_DIR/default "* ]]
}

@test "t3779: THE FIELD CASE — unset, no hub in default, one canonical hub → supplied" {
    _hub "$TEST_TEMP_DIR/canon" live
    run fw_termlink_runtime_resolve
    [[ "$output" == "supplied $TEST_TEMP_DIR/canon "* ]]
    # resolve reports, it never mutates the caller's environment
    [ -z "${TERMLINK_RUNTIME_DIR:-}" ]
}

@test "t3779: a stale socket with a dead pid is not a hub → none" {
    _hub "$TEST_TEMP_DIR/canon" dead
    run fw_termlink_runtime_resolve
    [[ "$output" == none* ]]
}

@test "t3779: two live candidate hubs → ambiguous, never a guess" {
    mkdir -p "$TEST_TEMP_DIR/canon2"
    _hub "$TEST_TEMP_DIR/canon" live
    _hub "$TEST_TEMP_DIR/canon2" live
    TERMLINK_RUNTIME_DIR_FALLBACK="$TEST_TEMP_DIR/canon $TEST_TEMP_DIR/canon2" run fw_termlink_runtime_resolve
    [[ "$output" == ambiguous* ]]
}

@test "t3779: doctor WARNs when the env would register where no hub listens" {
    _hub "$TEST_TEMP_DIR/canon" live
    run fw_termlink_doctor_line
    [[ "$output" == "WARN TermLink split-brain:"* ]]
    [[ "$output" == *"export TERMLINK_RUNTIME_DIR=$TEST_TEMP_DIR/canon"* ]]
}

@test "t3779: doctor WARNs when THIS session is registered in a hub-less dir (env looks fine)" {
    _hub "$TEST_TEMP_DIR/canon" live
    touch "$TEST_TEMP_DIR/default/sessions/tl-x.json"
    TERMLINK_RUNTIME_DIR="$TEST_TEMP_DIR/canon" TERMLINK_SESSION_ID=tl-x run fw_termlink_doctor_line
    [[ "$output" == *"this session (tl-x) is registered in $TEST_TEMP_DIR/default"* ]]
}

@test "t3779: CONTROL — consistent registration prints nothing" {
    _hub "$TEST_TEMP_DIR/canon" live
    touch "$TEST_TEMP_DIR/canon/sessions/tl-x.json"
    TERMLINK_RUNTIME_DIR="$TEST_TEMP_DIR/canon" TERMLINK_SESSION_ID=tl-x run fw_termlink_doctor_line
    [ -z "$output" ]
    TERMLINK_RUNTIME_DIR="$TEST_TEMP_DIR/canon" run fw_termlink_doctor_line
    [ -z "$output" ]
}

@test "t3779: claude-fw resolves before spawning and exports only on 'supplied'" {
    local f="$FWROOT/bin/claude-fw"
    grep -q 'lib/termlink-runtime.sh' "$f"
    # the resolve happens before the spawn in termlink_start
    local r s
    r=$(grep -n '_tlrt=$(fw_termlink_runtime_resolve)' "$f" | cut -d: -f1)
    s=$(grep -n 'termlink spawn --name "$TERMLINK_SESSION"' "$f" | cut -d: -f1)
    [ -n "$r" ] && [ -n "$s" ] && [ "$r" -lt "$s" ]
    grep -q 'export TERMLINK_RUNTIME_DIR="${_tlrt%% \*}"' "$f"
}
