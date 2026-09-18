#!/usr/bin/env bats
# T-3382 / OBS-437 — the liveness rail decides `watchtower:` by IDENTITY, not
# by whether the root page answers inside two seconds.
#
# Observed 2026-09-17. agents/monitor/liveness-check.sh probed `curl -sf -m 2
# "$wt_url/"`. With Watchtower confirmed up (identity endpoint returning our
# project_root, review pages 200), the root page took 4.47s and 2.37s on
# consecutive hits, curl exited 28, and the rail wrote `stopped`. The log shows
# it had been doing so since ~2026-06-12 — two months of false negatives before
# the exec-bit death (T-3380) silenced the rail altogether. Two stacked bugs;
# this suite pins the second.
#
# The fix is not a longer timeout: `/` cannot say WHOSE server answered, and on
# the origin host :3000 belongs to another project (T-1376/T-2732). The rail now
# sources lib/watchtower.sh:_watchtower_identity_matches — the same handshake
# fw doctor and the launcher use — and records three states: running, foreign,
# stopped.
#
# The fixture reproduces the measured shape: `/` sleeps 3s, /api/_identity
# answers in ~1ms with a configurable project_root.

load ../test_helper

SCRIPT="$FRAMEWORK_ROOT/agents/monitor/liveness-check.sh"
FIXTURE="$FRAMEWORK_ROOT/tests/fixtures/slow_watchtower.py"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    # A stand-in PROJECT_ROOT: the script writes its samples under it and the
    # identity handshake compares against it.
    FAKE_ROOT="$TEST_TEMP_DIR/project"
    mkdir -p "$FAKE_ROOT/.context/working" "$FAKE_ROOT/.context/monitors"
    FIXTURE_PID=""
}

teardown() {
    [ -n "${FIXTURE_PID:-}" ] && kill "$FIXTURE_PID" 2>/dev/null
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# _start_fixture PROJECT_ROOT_TO_CLAIM  → prints the port
_start_fixture() {
    local out="$TEST_TEMP_DIR/fixture.port"
    python3 "$FIXTURE" "$out" "$1" 3 >/dev/null 2>&1 3>&- </dev/null &
    FIXTURE_PID=$!
    local i
    for i in $(seq 1 50); do
        [ -s "$out" ] && { cat "$out"; return 0; }
        sleep 0.1
    done
    return 1
}

# Run the rail against a URL, with the real framework libs available.
_run_rail() {
    printf 'http://127.0.0.1:%s\n' "$1" > "$FAKE_ROOT/.context/working/watchtower.url"
    PROJECT_ROOT="$FAKE_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        run bash "$SCRIPT"
}

_recorded_state() {
    sed -n 's/^watchtower: *//p' "$FAKE_ROOT/.context/monitors/liveness-latest.yaml"
}

@test "control leg: the OLD probe goes red against a server whose root page is slower than 2s" {
    port=$(_start_fixture "$FAKE_ROOT")
    run curl -sf -m 2 "http://127.0.0.1:$port/"
    [ "$status" -ne 0 ]          # exit 28 — this is the false negative, reproduced
    # ...while the identity endpoint answers the same server instantly
    run curl -sf -m 2 "http://127.0.0.1:$port/api/_identity"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"service": "watchtower"'* ]]
}

@test "the incident: a slow-but-ours Watchtower now reads running, not stopped" {
    port=$(_start_fixture "$FAKE_ROOT")
    _run_rail "$port"
    [ "$status" -eq 0 ]
    [ "$(_recorded_state)" = "running" ]
    tail -1 "$FAKE_ROOT/.context/monitors/liveness.jsonl" | grep -q '"watchtower":"running"'
}

@test "a server that answers but claims ANOTHER project_root reads foreign, never running" {
    port=$(_start_fixture "/opt/some-other-project")
    _run_rail "$port"
    [ "$status" -eq 0 ]
    [ "$(_recorded_state)" = "foreign" ]
}

@test "no server at all reads stopped" {
    # bind :0, read the port, release it — nothing listens there now
    port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
    _run_rail "$port"
    [ "$status" -eq 0 ]
    [ "$(_recorded_state)" = "stopped" ]
}

@test "sourcing lib/watchtower.sh under set -euo pipefail does not kill the rail" {
    port=$(_start_fixture "$FAKE_ROOT")
    _run_rail "$port"
    [ "$status" -eq 0 ]
    [ -s "$FAKE_ROOT/.context/monitors/liveness.jsonl" ]
}

@test "with the lib ABSENT the rail still exits 0 and degrades to foreign rather than dying" {
    port=$(_start_fixture "$FAKE_ROOT")
    printf 'http://127.0.0.1:%s\n' "$port" > "$FAKE_ROOT/.context/working/watchtower.url"
    # FRAMEWORK_ROOT pointed somewhere with no lib/ — the helper cannot load
    PROJECT_ROOT="$FAKE_ROOT" FRAMEWORK_ROOT="$TEST_TEMP_DIR/nolib" run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    # Something answered, but identity could not be verified: foreign is the
    # honest answer, and it is NOT running.
    [ "$(_recorded_state)" = "foreign" ]
}

@test "the old reachability probe is gone from the script" {
    ! grep -qE 'curl -sf -m 2 "\$\{wt_url%/\}/"' "$SCRIPT"
    grep -q '_watchtower_identity_matches' "$SCRIPT"
}
