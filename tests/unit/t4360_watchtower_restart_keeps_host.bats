#!/usr/bin/env bats
# T-4360 (GitHub #103) — a plain `watchtower restart` from a shell without FW_HOST
# (an agent session) re-resolved the bind to the 0.0.0.0 default and silently
# widened a host-specific instance to every interface. Restart must come back on
# the running address; an explicit FW_HOST still wins and WARNs when it widens.
#
# 127.0.0.2 is a second loopback address, so the test needs no LAN interface and a
# widened listener (0.0.0.0) is distinguishable from the kept one.

bats_require_minimum_version 1.5.0

ROOT() { echo "$BATS_TEST_DIRNAME/../.."; }
BOUND=127.0.0.2

setup() {
    command -v ss >/dev/null 2>&1 || skip "ss not installed"
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working"
    printf 'project_name: t4360\nversion: 1.0\n' > "$PROJ/.framework.yaml"
    PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.2",0));print(s.getsockname()[1]);s.close()')
}

teardown() {
    [ -n "${PROJ:-}" ] && env -u FW_HOST PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" \
        "$(ROOT)/bin/watchtower.sh" stop >/dev/null 2>&1 || true
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# wt [VAR=value ...] -- verb args: runs watchtower.sh with FW_HOST unset unless given.
wt() {
    local envs=()
    while [ "$1" != "--" ]; do envs+=("$1"); shift; done
    shift
    env -u FW_HOST PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" ${envs[@]+"${envs[@]}"} \
        "$(ROOT)/bin/watchtower.sh" "$@"
}

listener() { ss -tlnH 2>/dev/null | awk -v p=":$PORT" 'substr($4, length($4)-length(p)+1)==p {print $4}'; }

@test "start on one address records it in watchtower.host" {
    run wt FW_HOST=$BOUND -- start --port "$PORT"
    [ "$status" -eq 0 ]
    [ "$(cat "$PROJ/.context/working/watchtower.host")" = "$BOUND" ]
    [ "$(listener)" = "$BOUND:$PORT" ]
}

@test "restart without FW_HOST keeps the running address (does not widen)" {
    wt FW_HOST=$BOUND -- start --port "$PORT" >/dev/null 2>&1
    [ "$(listener)" = "$BOUND:$PORT" ]
    run wt -- restart --port "$PORT"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Keeping the running address $BOUND"* ]]
    [ "$(listener)" = "$BOUND:$PORT" ]
}

@test "an instance started before the host file existed is still kept (kernel fallback)" {
    wt FW_HOST=$BOUND -- start --port "$PORT" >/dev/null 2>&1
    rm -f "$PROJ/.context/working/watchtower.host"
    run wt -- restart --port "$PORT"
    echo "$output"
    [ "$status" -eq 0 ]
    [ "$(listener)" = "$BOUND:$PORT" ]
}

@test "explicit FW_HOST=0.0.0.0 wins and WARNs that it widens" {
    wt FW_HOST=$BOUND -- start --port "$PORT" >/dev/null 2>&1
    run wt FW_HOST=0.0.0.0 -- restart --port "$PORT"
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WIDENS Watchtower from $BOUND to 0.0.0.0"* ]]
    [ "$(listener)" = "0.0.0.0:$PORT" ]
}

@test "stop removes the host file with the rest of the triple" {
    wt FW_HOST=$BOUND -- start --port "$PORT" >/dev/null 2>&1
    wt -- stop >/dev/null 2>&1
    [ ! -f "$PROJ/.context/working/watchtower.host" ]
}
