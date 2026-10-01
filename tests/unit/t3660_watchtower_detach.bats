#!/usr/bin/env bats
# T-3660 — `fw serve` must outlive the shell that launched it, and `--debug`
# must run in the foreground (P-01 WSL F-16, F-17).
#
# Both cases start the REAL server through bin/watchtower.sh against a temp
# project on a free port. ufw is stubbed so the start path cannot touch the
# host firewall. Teardown kills only the pid this test's own server wrote.

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
    PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
    PIDF="$PROJ/.context/working/watchtower.pid"
    LAUNCHER_PID=""
}

teardown() {
    local p
    p=$(cat "$PIDF" 2>/dev/null || true)
    # Our own server only: the pid our temp project's pid file names, its
    # children (the --debug reloader), and the launcher this test started.
    for q in $p $LAUNCHER_PID; do
        pkill -KILL -P "$q" 2>/dev/null || true
        kill -KILL "$q" 2>/dev/null || true
    done
    rm -rf "${TEST_TEMP_DIR:?}"
}

# Wait up to N seconds for our server to answer /api/_identity for $PROJ.
_wait_identity() {
    local n="${1:-20}" i=0 out
    while [ "$i" -lt "$n" ]; do
        if out=$(curl -sf --max-time 2 "http://localhost:${PORT}/api/_identity" 2>/dev/null) \
            && [[ "$out" == *"\"project_root\":\"$PROJ\""* || "$out" == *"\"project_root\": \"$PROJ\""* ]]; then
            return 0
        fi
        sleep 1; i=$((i + 1))
    done
    return 1
}

@test "start: the server survives a hangup of the launching shell's process group" {
    # The launcher gets its own session/process group (as a terminal's shell
    # does), starts Watchtower, then lingers like an interactive shell would.
    PATH="$TEST_TEMP_DIR/bin:$PATH" PROJECT_ROOT="$PROJ" \
        setsid bash -c 'echo $$ > "$1/launcher.pid"; "$2/bin/watchtower.sh" start --port "$3" > "$1/start.out" 2>&1; sleep 120' \
        _ "$TEST_TEMP_DIR" "$FRAMEWORK_ROOT" "$PORT" 3>&- &
    _wait_identity 20
    LAUNCHER_PID=$(cat "$TEST_TEMP_DIR/launcher.pid")
    server_pid=$(cat "$PIDF")
    [ -n "$server_pid" ]

    # Terminal closes: SIGHUP to the whole process group of the launcher.
    kill -HUP -- "-$LAUNCHER_PID" 2>/dev/null || true
    sleep 2

    kill -0 "$server_pid"
    run curl -sf --max-time 2 "http://localhost:${PORT}/api/_identity"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$PROJ"* ]]
}

@test "start --debug: runs in the foreground — the launched process IS the server" {
    PATH="$TEST_TEMP_DIR/bin:$PATH" PROJECT_ROOT="$PROJ" \
        "$FRAMEWORK_ROOT/bin/watchtower.sh" start --port "$PORT" --debug \
        > "$TEST_TEMP_DIR/debug.out" 2>&1 3>&- &
    LAUNCHER_PID=$!
    _wait_identity 20
    sleep 1

    # Still running: a foreground start does not return while the server lives.
    kill -0 "$LAUNCHER_PID"
    # The pid file names the foreground process itself, not a background child.
    [ "$(cat "$PIDF")" = "$LAUNCHER_PID" ]
    # The serving pid is the foreground process or (Werkzeug reloader) its child.
    serving=$(curl -sf --max-time 2 "http://localhost:${PORT}/api/_identity" \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["pid"])')
    [ "$serving" = "$LAUNCHER_PID" ] || [ "$(ps -o ppid= -p "$serving" | tr -d ' ')" = "$LAUNCHER_PID" ]

    # `stop` from another shell ends it completely: the port is free afterwards,
    # including the reloader child.
    run env PROJECT_ROOT="$PROJ" "$FRAMEWORK_ROOT/bin/watchtower.sh" stop
    [ "$status" -eq 0 ]
    sleep 1
    run kill -0 "$serving"
    [ "$status" -ne 0 ]
    run curl -sf --max-time 2 "http://localhost:${PORT}/api/_identity"
    [ "$status" -ne 0 ]
}
