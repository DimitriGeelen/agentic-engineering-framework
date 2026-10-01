#!/usr/bin/env bats
# T-3627 — `fw watchtower restart` must keep the previous log. On 2026-10-01 a restart
# truncated watchtower.log and destroyed the only record of who sent ~60 concurrent
# /graduation requests to the wedged server.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    LOG="$TEST_TEMP_DIR/watchtower.log"
}

teardown() {
    rm -rf "${TEST_TEMP_DIR:?}"
}

_rotate() {
    bash -c 'source "'"$FRAMEWORK_ROOT"'/lib/watchtower.sh" 2>/dev/null; watchtower_rotate_log "$1" 3' _ "$LOG"
}

@test "rotate: previous log survives as .1" {
    echo "evidence" > "$LOG"
    run _rotate
    [ "$status" -eq 0 ]
    [ "$(cat "$LOG.1")" = "evidence" ]
    [ ! -e "$LOG" ]
}

@test "rotate: generations shift and the oldest beyond keep is dropped" {
    echo one > "$LOG"; _rotate
    echo two > "$LOG"; _rotate
    echo three > "$LOG"; _rotate
    echo four > "$LOG"; _rotate
    [ "$(cat "$LOG.1")" = "four" ]
    [ "$(cat "$LOG.2")" = "three" ]
    [ "$(cat "$LOG.3")" = "two" ]
    [ ! -e "$LOG.4" ]
}

@test "rotate: an empty or missing log does not displace .1" {
    echo kept > "$LOG.1"
    : > "$LOG"
    run _rotate
    [ "$status" -eq 0 ]
    [ "$(cat "$LOG.1")" = "kept" ]
}

@test "start path rotates instead of truncating" {
    run grep -n 'watchtower_rotate_log "\$LOG_FILE"' "$FRAMEWORK_ROOT/bin/watchtower.sh"
    [ "$status" -eq 0 ]
}
