#!/usr/bin/env bats
# T-4306 — a pid file whose process is gone or a ZOMBIE (exited, never reaped)
# is a stopped Watchtower. `kill -0` succeeds on a zombie, so before the fix
# stop failed and left the pid file, and start/restart then refused to run.
#
# Runs against a temp PROJECT_ROOT so it never reads this repo's own pid file.
# The start/restart cases launch a real server on a free port (ufw stubbed);
# teardown kills only the pid that server wrote and the zombie's parent.

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
    W="$PROJ/.context/working"
    PIDF="$W/watchtower.pid"
    ZPARENT=""
}

teardown() {
    local p
    p=$(cat "$PIDF" 2>/dev/null || true)
    if [ -n "$p" ] && [ "$p" != "${ZOMBIE:-}" ] && kill -0 "$p" 2>/dev/null; then
        pkill -KILL -P "$p" 2>/dev/null || true
        kill -KILL "$p" 2>/dev/null || true
    fi
    [ -n "$ZPARENT" ] && kill -KILL "$ZPARENT" 2>/dev/null || true
    rm -rf "${TEST_TEMP_DIR:?}"
}

# A pid that is certainly dead: a child we started and reaped.
_dead_pid() {
    bash -c 'exit 0' &
    DEAD=$!
    wait "$DEAD"
}

# A real zombie: a parent that forks a child which exits at once, and then
# sleeps without ever waiting for it.
_zombie_pid() {
    python3 -c '
import os, sys, time
pid = os.fork()
if pid == 0:
    os._exit(0)
print(pid, flush=True)
time.sleep(300)
' > "$TEST_TEMP_DIR/zpid" 3>&- &
    ZPARENT=$!
    local i
    for i in $(seq 1 50); do
        [ -s "$TEST_TEMP_DIR/zpid" ] && break
        sleep 0.1
    done
    ZOMBIE=$(tr -d '[:space:]' < "$TEST_TEMP_DIR/zpid")
    for i in $(seq 1 50); do
        [ "$(sed 's/.*) //' "/proc/$ZOMBIE/stat" 2>/dev/null | cut -d' ' -f1)" = "Z" ] && break
        sleep 0.1
    done
    # Precondition: kill -0 still succeeds — this is exactly what fooled the script.
    kill -0 "$ZOMBIE"
    [ "$(sed 's/.*) //' "/proc/$ZOMBIE/stat" | cut -d' ' -f1)" = "Z" ]
}

_triple() {
    echo "$1" > "$PIDF"
    echo "65000" > "$W/watchtower.port"
    echo "http://localhost:65000" > "$W/watchtower.url"
}

_free_port() {
    python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'
}

_wt() {
    run env PATH="$TEST_TEMP_DIR/bin:$PATH" PROJECT_ROOT="$PROJ" \
        "$FRAMEWORK_ROOT/bin/watchtower.sh" "$@" 3>&-
}

@test "stop: dead pid -> exit 0, triple removed" {
    _dead_pid
    _triple "$DEAD"
    _wt stop
    [ "$status" -eq 0 ]
    [ ! -f "$PIDF" ] && [ ! -f "$W/watchtower.port" ] && [ ! -f "$W/watchtower.url" ]
}

@test "stop: zombie pid -> exit 0, reported stopped, triple removed" {
    _zombie_pid
    _triple "$ZOMBIE"
    _wt stop
    [ "$status" -eq 0 ]
    [[ "$output" != *"Failed to stop"* ]]
    [ ! -f "$PIDF" ] && [ ! -f "$W/watchtower.port" ] && [ ! -f "$W/watchtower.url" ]
}

@test "start: dead pid file is stale -> server starts" {
    _dead_pid
    echo "$DEAD" > "$PIDF"
    port=$(_free_port)
    _wt start --port "$port"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Watchtower is running"* ]]
    [ "$(cat "$PIDF")" != "$DEAD" ]
}

@test "start: zombie pid file is stale -> server starts" {
    _zombie_pid
    echo "$ZOMBIE" > "$PIDF"
    port=$(_free_port)
    _wt start --port "$port"
    [ "$status" -eq 0 ]
    [[ "$output" != *"already running"* ]]
    [[ "$output" == *"Watchtower is running"* ]]
    [ "$(cat "$PIDF")" != "$ZOMBIE" ]
}

@test "restart: dead pid file -> server starts" {
    _dead_pid
    echo "$DEAD" > "$PIDF"
    port=$(_free_port)
    _wt restart --port "$port"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Watchtower is running"* ]]
    [ "$(cat "$PIDF")" != "$DEAD" ]
}

@test "restart: zombie pid file -> server starts" {
    _zombie_pid
    echo "$ZOMBIE" > "$PIDF"
    port=$(_free_port)
    _wt restart --port "$port"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Failed to stop"* ]]
    [[ "$output" == *"Watchtower is running"* ]]
    [ "$(cat "$PIDF")" != "$ZOMBIE" ]
}

@test "status: zombie pid file reads as stale, not running" {
    _zombie_pid
    echo "$ZOMBIE" > "$PIDF"
    _wt status
    [ "$status" -eq 1 ]
    [[ "$output" == *"Stale PID file"* ]]
}
