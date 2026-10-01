#!/usr/bin/env bats
# T-3661 — `fw watchtower status` must be a predicate a script can branch on
# (P-01 WSL F-25). LSB-style codes: 0 running, 1 stale pid file, 3 not running.
#
# Runs against a temp PROJECT_ROOT so it never reads this repo's own pid file.
# The running case starts a real server on a free port (ufw stubbed) and
# teardown kills only the pid that server wrote.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    PROJ="$TEST_TEMP_DIR/project"
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active" "$PROJ/.tasks/completed"
    mkdir -p "$TEST_TEMP_DIR/bin"
    printf '#!/bin/sh\necho "Status: inactive"\n' > "$TEST_TEMP_DIR/bin/ufw"
    chmod +x "$TEST_TEMP_DIR/bin/ufw"
    PIDF="$PROJ/.context/working/watchtower.pid"
}

teardown() {
    local p
    p=$(cat "$PIDF" 2>/dev/null || true)
    if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
        pkill -KILL -P "$p" 2>/dev/null || true
        kill -KILL "$p" 2>/dev/null || true
    fi
    rm -rf "${TEST_TEMP_DIR:?}"
}

_status() {
    run env PROJECT_ROOT="$PROJ" "$FRAMEWORK_ROOT/bin/watchtower.sh" status
}

@test "status: nothing running, no pid file -> exit 3" {
    _status
    [ "$status" -eq 3 ]
    [[ "$output" == *"not running"* ]]
}

@test "status: stale pid file -> exit 1" {
    # A pid that is certainly dead: a child we started and reaped.
    bash -c 'exit 0' &
    dead=$!
    wait "$dead"
    echo "$dead" > "$PIDF"
    _status
    [ "$status" -eq 1 ]
    [[ "$output" == *"Stale PID file"* ]]
}

@test "status: our server running -> exit 0" {
    port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
    run env PATH="$TEST_TEMP_DIR/bin:$PATH" PROJECT_ROOT="$PROJ" \
        "$FRAMEWORK_ROOT/bin/watchtower.sh" start --port "$port" 3>&-
    [ "$status" -eq 0 ]
    _status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Watchtower is running"* ]]
}

@test "status: the exit codes are documented in the help text" {
    run "$FRAMEWORK_ROOT/bin/watchtower.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"exit 0 running, 1 stale PID file, 3 not running"* ]]
}
