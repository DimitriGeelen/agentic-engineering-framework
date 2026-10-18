#!/usr/bin/env bats
# T-4332 (dimitri-mint-dev T-133 F-08) — `watchtower start` printed
# "Health check passed" and exited 1. Cause: `lan_ip=$(detect_lan_ip)` runs
# under `set -euo pipefail`; with no `ip` command (or no global IPv4 address,
# the container shape) the grep stage exits 1, the pipeline fails, the
# assignment fails, and errexit kills the script right after the success line.
#
# The test runs a real start on a free port with `ip` and `ufw` hidden from PATH
# (a symlink farm of the host's PATH minus those two), and stops what it started.

bats_require_minimum_version 1.5.0

ROOT() { echo "$BATS_TEST_DIRNAME/../.."; }

setup_file() {
    # PATH with every command the host has, except ip and ufw. Built once: it
    # links every executable on the host PATH.
    export BIN="$BATS_FILE_TMPDIR/bin"
    mkdir -p "$BIN"
    local d f name
    IFS=: read -ra dirs <<< "$PATH"
    for d in "${dirs[@]}"; do
        [ -d "$d" ] || continue
        for f in "$d"/*; do
            name=${f##*/}
            case "$name" in ip|ufw) continue ;; esac
            if [ -x "$f" ] && [ ! -e "$BIN/$name" ]; then ln -s "$f" "$BIN/$name"; fi
        done
    done
}

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    PROJ="$TEST_TEMP_DIR/proj"
    mkdir -p "$PROJ/.context/working"
    printf 'project_name: t4332\nversion: 1.0\n' > "$PROJ/.framework.yaml"
    PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
}

teardown() {
    PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" "$(ROOT)/bin/watchtower.sh" stop >/dev/null 2>&1 || true
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

@test "the stripped PATH really has no ip and no ufw" {
    run env PATH="$BIN" bash -c 'command -v ip || command -v ufw'
    [ "$status" -ne 0 ]
}

@test "detect_lan_ip returns 0 with empty output when ip is missing" {
    run env PATH="$BIN" bash -c 'set -euo pipefail; eval "$(sed -n "/^detect_lan_ip()/,/^}/p" "$1")"; x=$(detect_lan_ip); printf "[%s]" "$x"' _ "$(ROOT)/bin/watchtower.sh"
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}

@test "start with no ip/ufw: Health check passed means exit 0, triple written" {
    run env PATH="$BIN" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" FW_HOST=0.0.0.0 \
        "$(ROOT)/bin/watchtower.sh" start --port "$PORT"
    [[ "$output" == *"Health check passed"* ]]
    [ "$status" -eq 0 ]
    [[ "$output" == *"Watchtower is running"* ]]
    [ "$(tr -d '[:space:]' < "$PROJ/.context/working/watchtower.port")" = "$PORT" ]
    [ "$(tr -d '[:space:]' < "$PROJ/.context/working/watchtower.url")" = "http://localhost:$PORT" ]
}

@test "url with no ip while running: exit 0, localhost url" {
    env PATH="$BIN" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" FW_HOST=0.0.0.0 \
        "$(ROOT)/bin/watchtower.sh" start --port "$PORT" >/dev/null 2>&1
    run env PATH="$BIN" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$(ROOT)" FW_HOST=0.0.0.0 \
        "$(ROOT)/bin/watchtower.sh" url
    [ "$status" -eq 0 ]
    [ "$output" = "http://localhost:$PORT" ]
}
