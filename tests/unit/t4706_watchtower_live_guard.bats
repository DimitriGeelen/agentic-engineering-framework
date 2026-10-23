#!/usr/bin/env bats
# T-4706 — the live Watchtower was killed on 2026-10-23 at 13:27:36Z and stayed
# down ~1h47m; nothing restarted it and nothing said so.
#
# Three legs, each tested against a FAKE live checkout (a temp git repo whose
# "Watchtower" is a `sleep`), so no case here can touch the operator's server:
#   1. bin/watchtower.sh refuses start/stop/restart/ensure from a test whose
#      PROJECT_ROOT is the checkout the test runs from;
#   2. tests/live_repo_guard.bash fails a test that kills or replaces the live pid;
#   3. the ensure keep-alive records an outage and fw doctor WARNs on it.

load ../test_helper
load ../live_repo_guard

setup() {
    FWROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    LIVE="$TEST_TEMP_DIR/live"
    mkdir -p "$LIVE/tests/unit" "$LIVE/.context/working"
    git -C "$LIVE" init -q
    touch "$LIVE/tests/unit/fake.bats"
    sleep 300 &
    FAKE_PID=$!
    echo "$FAKE_PID" > "$LIVE/.context/working/watchtower.pid"
    unset FW_WATCHTOWER_ALLOW_LIVE_IN_TEST FW_WATCHTOWER_ENSURE FW_DISPATCHED_WORKER FW_REVIEW_WORKER
}

teardown() {
    kill "$FAKE_PID" 2>/dev/null || true
    [ -n "${FAKE2:-}" ] && kill "$FAKE2" 2>/dev/null || true
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
    return 0
}

# Run watchtower.sh as if from a test file inside the fake live checkout.
_wt_as_live_test() {
    BATS_TEST_FILENAME="$LIVE/tests/unit/fake.bats" PROJECT_ROOT="$LIVE" FRAMEWORK_ROOT="$FWROOT" \
        bash "$FWROOT/bin/watchtower.sh" "$@"
}

@test "t4706: stop from a test whose PROJECT_ROOT is the live checkout is refused; the server lives" {
    run _wt_as_live_test stop
    [ "$status" -eq 4 ]
    [[ "$output" == *"live checkout"* ]]
    kill -0 "$FAKE_PID"
}

@test "t4706: start and restart are refused the same way" {
    run _wt_as_live_test restart
    [ "$status" -eq 4 ]
    run _wt_as_live_test start --port 1
    [ "$status" -eq 4 ]
    kill -0 "$FAKE_PID"
}

@test "t4706: a temp PROJECT_ROOT is not refused (the control leg)" {
    mkdir -p "$TEST_TEMP_DIR/other/.context/working"
    BATS_TEST_FILENAME="$LIVE/tests/unit/fake.bats" PROJECT_ROOT="$TEST_TEMP_DIR/other" FRAMEWORK_ROOT="$FWROOT" \
        run bash "$FWROOT/bin/watchtower.sh" stop
    [ "$status" -eq 0 ]
    [[ "$output" == *"No PID file"* ]]
}

@test "t4706: FW_WATCHTOWER_ALLOW_LIVE_IN_TEST=1 lets the stop through" {
    FW_WATCHTOWER_ALLOW_LIVE_IN_TEST=1 run _wt_as_live_test stop
    [ "$status" -eq 0 ]
    ! kill -0 "$FAKE_PID" 2>/dev/null || false
}

@test "t4706: live_repo_guard fails when the live Watchtower pid dies during the test" {
    live_repo_guard_begin "$LIVE"
    kill "$FAKE_PID"; wait "$FAKE_PID" 2>/dev/null || true
    run live_repo_guard_end
    [ "$status" -eq 1 ]
    [[ "$output" == *"LIVE REPO GUARD (T-4706)"* ]]
    [[ "$output" == *"-> dead"* ]]
}

@test "t4706: live_repo_guard fails when the live Watchtower is replaced, passes when untouched" {
    live_repo_guard_begin "$LIVE"
    run live_repo_guard_end
    [ "$status" -eq 0 ]
    sleep 300 & FAKE2=$!
    echo "$FAKE2" > "$LIVE/.context/working/watchtower.pid"
    run live_repo_guard_end
    [ "$status" -eq 1 ]
    [[ "$output" == *"pid $FAKE_PID -> $FAKE2"* ]]
}

# Stub launcher: status says "stale pid file", start succeeds.
_ensure_stub() {
    STUB="$TEST_TEMP_DIR/wt-stub.sh"
    printf '#!/usr/bin/env bash\ncase "$1" in status) exit 1 ;; start) exit 0 ;; esac\n' > "$STUB"
    chmod +x "$STUB"
}

@test "t4706: ensure records an outage when a pid file shows it had been running" {
    _ensure_stub
    P="$TEST_TEMP_DIR/proj"; mkdir -p "$P/.context/working"
    echo 4242 > "$P/.context/working/watchtower.pid"
    echo x > "$P/.context/working/watchtower.log"
    run bash -c "export PROJECT_ROOT='$P' FRAMEWORK_ROOT='$FWROOT' FW_WATCHTOWER_SH='$STUB' FW_WATCHTOWER_ENSURE_BY=cron
        . '$FWROOT/lib/watchtower-ensure.sh'; fw_watchtower_ensure; fw_watchtower_recent_outages"
    [ "$status" -eq 0 ]
    [[ "$output" == *"last_pid=4242"* ]]
    [[ "$output" == *"result=restarted"* ]]
    grep -q '"by":"cron"' "$P/.context/working/watchtower-outages.jsonl"
}

@test "t4706: a first start (no pid or url file) is not an outage" {
    _ensure_stub
    P="$TEST_TEMP_DIR/fresh"; mkdir -p "$P/.context/working"
    run bash -c "export PROJECT_ROOT='$P' FRAMEWORK_ROOT='$FWROOT' FW_WATCHTOWER_SH='$STUB'
        . '$FWROOT/lib/watchtower-ensure.sh'; fw_watchtower_ensure; fw_watchtower_recent_outages"
    [ "$status" -eq 1 ]
    [ ! -e "$P/.context/working/watchtower-outages.jsonl" ]
}

@test "t4706: an outage older than the window is not reported" {
    P="$TEST_TEMP_DIR/old"; mkdir -p "$P/.context/working"
    echo '{"detected":"2020-01-01T00:00:00Z","down_since":"","last_pid":"1","result":"restarted","by":"cron"}' \
        > "$P/.context/working/watchtower-outages.jsonl"
    run bash -c "export PROJECT_ROOT='$P'; . '$FWROOT/lib/watchtower-ensure.sh'; fw_watchtower_recent_outages"
    [ "$status" -eq 1 ]
}

@test "t4706: fw doctor WARNs on a recent Watchtower outage" {
    # Doctor's block is sourced in isolation: the whole doctor run reads the live host.
    grep -q 'fw_watchtower_recent_outages' "$FWROOT/bin/fw"
    P="$TEST_TEMP_DIR/doc"; mkdir -p "$P/.context/working"
    printf '{"detected":"%s","down_since":"x","last_pid":"7","result":"restarted","by":"cron"}\n' \
        "$(date -u +%FT%TZ)" > "$P/.context/working/watchtower-outages.jsonl"
    block=$(awk '/T-4706: Watchtower was killed and stayed down/{f=1} f{print} f && /^    fi$/{exit}' "$FWROOT/bin/fw")
    [ -n "$block" ]
    run bash -c "YELLOW= NC= ; warnings=0; FRAMEWORK_ROOT='$FWROOT' PROJECT_ROOT='$P'
        f() { $block
        echo warnings=\$warnings; }; f"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"*"Watchtower was down: 1 outage(s)"* ]]
    [[ "$output" == *"warnings=1"* ]]
}

@test "t4706: the cron registry runs the keep-alive" {
    grep -q "id: watchtower-ensure-5m" "$FWROOT/.context/cron-registry.yaml"
    grep -q "watchtower ensure" "$FWROOT/.context/cron/agentic-audit.crontab"
}
