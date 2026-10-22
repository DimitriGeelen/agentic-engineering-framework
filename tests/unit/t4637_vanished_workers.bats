#!/usr/bin/env bats
# T-4637 (T-4635 RCA) — a dispatch worker killed without writing exit_code must read
# VANISHED, not "running" forever. Fixture FW_DISPATCH_DIR only, never /tmp/tl-dispatch.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../../agents/termlink/termlink.sh"
    T="$(mktemp -d)"
    D="$T/dispatch"
    mkdir -p "$D" "$T/bin"
    export FW_DISPATCH_DIR="$D"
    export PROJECT_ROOT="$T/proj"
    mkdir -p "$PROJECT_ROOT"
    # fake termlink: cmd_status needs one on PATH; it lists no sessions
    printf '#!/bin/sh\nexit 0\n' > "$T/bin/termlink"
    chmod +x "$T/bin/termlink"
    export PATH="$T/bin:$PATH"
    LIVE_PID=""
}

teardown() {
    [ -n "$LIVE_PID" ] && kill "$LIVE_PID" 2>/dev/null || true
    rm -rf "$T"
}

mk() {  # name — a worker dir with meta + output aged 30 minutes
    mkdir -p "$D/$1"
    printf '{\n  "name": "%s",\n  "project": "%s",\n  "timeout": 60\n}\n' "$1" "$PROJECT_ROOT" > "$D/$1/meta.json"
    echo '{"type":"assistant"}' > "$D/$1/result.jsonl"
    touch -d '30 minutes ago' "$D/$1/result.jsonl" "$D/$1"
}

@test "killed worker (no exit_code, no process, stale output) is VANISHED in status and vanished" {
    mk dead
    run bash "$SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"dead"*"status: VANISHED"* ]]
    run bash "$SCRIPT" vanished
    [ "$status" -eq 1 ]
    [[ "$output" == *"VANISHED"*"dead"* ]]
}

@test "fresh output, finished worker and live process are not VANISHED" {
    mk fresh; touch "$D/fresh/result.jsonl"
    mk done; echo 0 > "$D/done/exit_code"
    mk live
    printf '#!/bin/sh\nsleep 60\n' > "$D/live/run.sh"
    bash "$D/live/run.sh" & LIVE_PID=$!
    run bash "$SCRIPT" vanished
    [ "$status" -eq 0 ]
    [[ "$output" != *"VANISHED"* ]]
    run bash "$SCRIPT" status
    [[ "$output" == *"fresh"*"status: running"* ]]
    [[ "$output" == *"done"*"status: complete"* ]]
    [[ "$output" == *"live"*"status: running"* ]]
    [[ "$output" != *"VANISHED"* ]]
}

@test "dir with no result.jsonl falls back to the dir's own age; --minutes and --json" {
    mk setup; rm "$D/setup/result.jsonl"; touch -d '30 minutes ago' "$D/setup"
    run bash "$SCRIPT" vanished --minutes 60
    [ "$status" -eq 0 ]
    run bash "$SCRIPT" vanished --minutes 5 --json
    [ "$status" -eq 1 ]
    echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[0]["name"]=="setup", d'
    FW_TERMLINK_VANISHED_MINUTES=60 run bash "$SCRIPT" vanished
    [ "$status" -eq 0 ]
}

@test "bad --minutes and unknown option are refused" {
    run bash "$SCRIPT" vanished --minutes abc
    [ "$status" -ne 0 ]
    run bash "$SCRIPT" vanished --bogus
    [ "$status" -ne 0 ]
}
