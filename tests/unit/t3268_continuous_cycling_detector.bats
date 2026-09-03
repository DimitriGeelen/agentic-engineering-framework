#!/usr/bin/env bats
# T-3268 (G-099 what_remains) — G-099 fixed the "wrapper says armed but turn
# driver isn't" drift class and named, but did not build, the detector for a
# sibling class: `last_terminated_reason` (bin/claude-fw:388) is a one-way
# latch that replays verbatim on every restart attempt without re-evaluating
# whether the thing that set it is still true. `.stop-driver.log` records one
# `decision=stop reason=terminated[stored@TS](CAUSE)` line per attempt, and
# neither existing check (fw doctor's continuous-run block, audit.sh's
# check_continuous_run_turn_driver) reads that log — both only tail the
# separate continuous-run.jsonl ledger.
#
# `fw_continuous_cycling_facts <root> <window_seconds> <threshold>` closes
# that gap: it counts repeats of an identical (stored_ts, cause) pair in
# .stop-driver.log within a trailing window and prints one tab-separated fact
# line when a pair recurs at/above threshold, nothing otherwise.

load ../test_helper

CONTINUOUS_MODE_LIB="$FRAMEWORK_ROOT/lib/continuous-mode.sh"

setup() {
    command -v python3 >/dev/null || skip "python3 unavailable"
    TEST_TEMP_DIR="$(mktemp -d)"
    mkdir -p "$TEST_TEMP_DIR/.context/working"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# write_log LINES... — each arg is "OFFSET_SECONDS STORED_TS CAUSE", writing a
# .stop-driver.log line timestamped OFFSET_SECONDS before "now".
write_log() {
    local log="$TEST_TEMP_DIR/.context/working/.stop-driver.log"
    : > "$log"
    local now offset stored cause ts
    now=$(date -u +%s)
    for spec in "$@"; do
        # word-splitting (not cut -d' ') so extra alignment spaces in the
        # call sites collapse instead of shifting field numbers
        read -r offset stored cause <<< "$spec"
        ts=$(date -u -d "@$((now - offset))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
             || date -u -r "$((now - offset))" +%Y-%m-%dT%H:%M:%SZ)
        echo "${ts} decision=stop reason=terminated[stored@${stored}](${cause})" >> "$log"
    done
}

run_facts() {
    run bash -c "source '$CONTINUOUS_MODE_LIB'; fw_continuous_cycling_facts '$TEST_TEMP_DIR' ${1:-3600} ${2:-3}"
}

@test "3+ identical stale lines within window: detected, count and span reported" {
    write_log \
        "600  2026-09-03T18:24:48Z human-gate:human-ac:T-3263" \
        "300  2026-09-03T18:24:48Z human-gate:human-ac:T-3263" \
        "60   2026-09-03T18:24:48Z human-gate:human-ac:T-3263"
    run_facts 3600 3
    [ "$status" -eq 0 ]
    [[ "$output" == *$'\t'"2026-09-03T18:24:48Z"$'\t'"human-gate:human-ac:T-3263"* ]]
    count=$(printf '%s' "$output" | cut -f1)
    [ "$count" -eq 3 ]
}

@test "below threshold (2 repeats, threshold 3): silent" {
    write_log \
        "600 2026-09-03T18:24:48Z human-gate:human-ac:T-3263" \
        "60  2026-09-03T18:24:48Z human-gate:human-ac:T-3263"
    run_facts 3600 3
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "all-distinct reasons: never groups, silent regardless of total line count" {
    write_log \
        "600 2026-09-03T10:00:00Z reason-a" \
        "500 2026-09-03T11:00:00Z reason-b" \
        "400 2026-09-03T12:00:00Z reason-c" \
        "300 2026-09-03T13:00:00Z reason-d"
    run_facts 3600 3
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "identical lines OUTSIDE the window: silent (proves the window bound, not just the count)" {
    write_log \
        "7200 2026-09-03T18:24:48Z human-gate:human-ac:T-3263" \
        "7100 2026-09-03T18:24:48Z human-gate:human-ac:T-3263" \
        "7000 2026-09-03T18:24:48Z human-gate:human-ac:T-3263"
    run_facts 3600 3
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "mixed: identical pair recurs 3x inside window, plus 2 more of the same pair outside it — only the in-window 3 count" {
    write_log \
        "7200 2026-09-03T18:24:48Z human-gate:human-ac:T-3263" \
        "7100 2026-09-03T18:24:48Z human-gate:human-ac:T-3263" \
        "600  2026-09-03T18:24:48Z human-gate:human-ac:T-3263" \
        "300  2026-09-03T18:24:48Z human-gate:human-ac:T-3263" \
        "60   2026-09-03T18:24:48Z human-gate:human-ac:T-3263"
    run_facts 3600 3
    [ "$status" -eq 0 ]
    count=$(printf '%s' "$output" | cut -f1)
    [ "$count" -eq 3 ]
}

@test "no .stop-driver.log at all: silent, exits 0 (fail-safe posture)" {
    run_facts 3600 3
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "empty .stop-driver.log: silent, exits 0" {
    : > "$TEST_TEMP_DIR/.context/working/.stop-driver.log"
    run_facts 3600 3
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
