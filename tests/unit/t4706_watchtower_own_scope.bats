#!/usr/bin/env bats
# T-4706 — placement. `bin/watchtower.sh start` detached the server with setsid
# only, so it stayed in its LAUNCHER's systemd unit: a dispatch worker's scope,
# or 055's agentic-fleet-cockpit.service when the parent session started it.
# Stopping that unit SIGKILLs the server and leaves no userspace record (the
# most likely class behind the 2026-10-23 13:27:36Z kill).
#
# start/restart now run the server in a scope of its own (aef.slice,
# aef-watchtower-*.scope) through lib/agent-scope.sh. Every case here starts a
# THROWAWAY server: temp PROJECT_ROOT, free port, ufw stubbed. Teardown kills
# only the pid our temp project's pid file names; the live server is never
# addressed.

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
    unset FW_AGENT_SCOPE FW_AGENT_SCOPE_SYSTEMD_DIR FW_WATCHTOWER_SLICE FW_WATCHTOWER_ALLOW_LIVE_IN_TEST
    SEEN_PIDS=""
}

teardown() {
    local p
    for p in $SEEN_PIDS $(cat "$PIDF" 2>/dev/null || true); do
        kill -KILL "$p" 2>/dev/null || true
    done
    rm -rf "${TEST_TEMP_DIR:?}"
}

_need_systemd() {
    command -v systemd-run >/dev/null 2>&1 && [ -d /run/systemd/system ] \
        || skip "no systemd on this host"
    systemd-run --scope --quiet --collect --no-ask-password --slice=aef.slice -- true >/dev/null 2>&1 \
        || skip "systemd refuses a system scope to uid $(id -u)"
}

_wt() {   # run bin/watchtower.sh against the temp project
    PATH="$TEST_TEMP_DIR/bin:$PATH" PROJECT_ROOT="$PROJ" \
        "$FRAMEWORK_ROOT/bin/watchtower.sh" "$@" > "$TEST_TEMP_DIR/wt.out" 2>&1 3>&-
}

_server_pid() {
    local p
    p=$(cat "$PIDF")
    SEEN_PIDS="$SEEN_PIDS $p"
    echo "$p"
}

@test "t4706: start runs the server in its own aef-watchtower scope, not the caller's unit" {
    _need_systemd
    _wt start --port "$PORT" || { cat "$TEST_TEMP_DIR/wt.out"; false; }
    pid=$(_server_pid)
    cg=$(cat "/proc/$pid/cgroup")
    echo "server: $cg  test: $(cat /proc/self/cgroup)"
    [[ "$cg" == *"/aef.slice/aef-watchtower-"*".scope" ]]
    [ "$cg" != "$(cat /proc/self/cgroup)" ]
    # $! survived the prefix: the pid on file is the process that serves the port
    run curl -sf --max-time 5 "http://127.0.0.1:${PORT}/api/_identity"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$PROJ"* ]]
    ss -tlnp 2>/dev/null | grep ":${PORT} " | grep -q "pid=${pid},"
}

@test "t4706: restart puts the new server in a new own scope" {
    _need_systemd
    _wt start --port "$PORT" || { cat "$TEST_TEMP_DIR/wt.out"; false; }
    first=$(_server_pid)
    first_cg=$(cat "/proc/$first/cgroup")
    _wt restart || { cat "$TEST_TEMP_DIR/wt.out"; false; }
    second=$(_server_pid)
    [ "$second" != "$first" ]
    cg=$(cat "/proc/$second/cgroup")
    [[ "$cg" == *"/aef.slice/aef-watchtower-"*".scope" ]]
    [ "$cg" != "$first_cg" ]
}

@test "t4706: FW_AGENT_SCOPE=0 starts the server without a scope (the control leg)" {
    FW_AGENT_SCOPE=0 _wt start --port "$PORT" || { cat "$TEST_TEMP_DIR/wt.out"; false; }
    pid=$(_server_pid)
    [ "$(cat "/proc/$pid/cgroup")" = "$(cat /proc/self/cgroup)" ]
    ! grep -q "WARNING" "$TEST_TEMP_DIR/wt.out" || false
}

@test "t4706: without systemd the start falls back cleanly, warns once and logs it" {
    FW_AGENT_SCOPE_SYSTEMD_DIR="$TEST_TEMP_DIR/no-systemd" _wt start --port "$PORT" \
        || { cat "$TEST_TEMP_DIR/wt.out"; false; }
    pid=$(_server_pid)
    kill -0 "$pid"
    [ "$(cat "/proc/$pid/cgroup")" = "$(cat /proc/self/cgroup)" ]
    grep -q "watchtower runs without its own systemd scope" "$TEST_TEMP_DIR/wt.out"
    grep -q "label=watchtower reason=systemd is not the init system" "$PROJ/.context/working/agent-scope.log"
}

@test "t4706: a named unit gets its own scope even inside the slice (prefix, stub systemd-run)" {
    printf '#!/bin/sh\nexit 0\n' > "$TEST_TEMP_DIR/bin/systemd-run"
    chmod +x "$TEST_TEMP_DIR/bin/systemd-run"
    mkdir -p "$TEST_TEMP_DIR/systemd"
    echo "0::/aef.slice/aef-watchtower-1.scope" > "$TEST_TEMP_DIR/cgroup.in"
    run env PATH="$TEST_TEMP_DIR/bin:$PATH" PROJECT_ROOT="$PROJ" \
        FW_AGENT_SCOPE_SYSTEMD_DIR="$TEST_TEMP_DIR/systemd" FW_AGENT_SCOPE_CGROUP_FILE="$TEST_TEMP_DIR/cgroup.in" \
        bash -c '. "$1/lib/agent-scope.sh"; FW_AGENT_SLICE=aef.slice fw_agent_scope_prefix watchtower aef-watchtower-9
            printf "%s\n" ${FW_AGENT_SCOPE_CMD[@]+"${FW_AGENT_SCOPE_CMD[@]}"}' _ "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ]
    grep -qx -- "--unit=aef-watchtower-9" <<<"$output"
    grep -qx -- "--slice=aef.slice" <<<"$output"
    # without a unit, the in-slice caller still gets no nested scope (T-4636 unchanged)
    run env PATH="$TEST_TEMP_DIR/bin:$PATH" PROJECT_ROOT="$PROJ" \
        FW_AGENT_SCOPE_SYSTEMD_DIR="$TEST_TEMP_DIR/systemd" FW_AGENT_SCOPE_CGROUP_FILE="$TEST_TEMP_DIR/cgroup.in" \
        bash -c '. "$1/lib/agent-scope.sh"; FW_AGENT_SLICE=aef.slice fw_agent_scope_prefix watchtower
            printf "%s\n" ${FW_AGENT_SCOPE_CMD[@]+"${FW_AGENT_SCOPE_CMD[@]}"}' _ "$FRAMEWORK_ROOT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
