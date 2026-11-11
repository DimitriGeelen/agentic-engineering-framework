#!/usr/bin/env bats
# T-4239 (dimitri-mint-dev T-118 claim 11; GitHub #103) — Watchtower has no login and
# can record Human decisions, yet a fresh start with nothing configured listened on
# every interface. The default is now 127.0.0.1 (operator, 2026-11-11); opening it
# to the network is an explicit `fw config set HOST 0.0.0.0`.

bats_require_minimum_version 1.5.0

ROOT() { echo "$BATS_TEST_DIRNAME/../.."; }

setup() {
    command -v ss >/dev/null 2>&1 || skip "ss not installed"
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active" "$PROJ/.tasks/completed"
    printf 'project_name: t4239\nversion: 1.0\n' > "$PROJ/.framework.yaml"
    PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
}

teardown() {
    [ -n "${PROJ:-}" ] && env -u FW_HOST PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" \
        "$(ROOT)/bin/watchtower.sh" stop >/dev/null 2>&1 || true
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

wt() { env -u FW_HOST PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" "$@"; }
listener() { ss -tlnH 2>/dev/null | awk -v p=":$PORT" 'substr($4, length($4)-length(p)+1)==p {print $4}'; }

@test "T-4239: a fresh start with no FW_HOST and no HOST setting listens on 127.0.0.1 only" {
    run wt "$(ROOT)/bin/watchtower.sh" start --port "$PORT"
    echo "$output"
    [ "$status" -eq 0 ]
    [ "$(listener)" = "127.0.0.1:$PORT" ]
    [ "$(cat "$PROJ/.context/working/watchtower.url")" = "http://127.0.0.1:$PORT" ]
}

@test "T-4239: HOST 0.0.0.0 in .framework.yaml opens it to every interface" {
    printf 'HOST: 0.0.0.0\n' >> "$PROJ/.framework.yaml"
    run wt "$(ROOT)/bin/watchtower.sh" start --port "$PORT"
    [ "$status" -eq 0 ]
    [ "$(listener)" = "0.0.0.0:$PORT" ]
}

@test "T-4239: fw doctor names the one command to open it to the network" {
    wt "$(ROOT)/bin/watchtower.sh" start --port "$PORT" >/dev/null 2>&1
    run wt "$(ROOT)/bin/fw" doctor --quick
    [[ "$output" == *"Watchtower answers on this machine only"*"fw config set HOST 0.0.0.0"* ]]
}

@test "T-4239: every place that resolves the default agrees on 127.0.0.1" {
    grep -q '"HOST|127.0.0.1|' "$(ROOT)/lib/config.sh"
    grep -q '("HOST", "127.0.0.1",' "$(ROOT)/web/blueprints/config.py"
    grep -q 'os.environ.get("FW_HOST", "127.0.0.1")' "$(ROOT)/web/config.py"
    ! grep -nE 'fw_config "HOST" "0\.0\.0\.0"|FW_HOST:-0\.0\.0\.0' "$(ROOT)/bin/watchtower.sh" "$(ROOT)/lib/watchtower.sh"
}
