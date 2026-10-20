#!/usr/bin/env bats
# T-4464: fw runme watch --until start|exit — an agent can report "it began" at the
# START marker, then arm a second watch for EXIT. Drives lib/runme.sh against a fake
# run.log in a temp project (same harness shape as t3675_runme.bats).

setup() {
    LIB="$BATS_TEST_DIRNAME/../../lib/runme.sh"
    TMPP="$(mktemp -d)"
    FW="$BATS_TEST_TMPDIR/fw-runme"
    printf '#!/bin/bash\nset -euo pipefail\nexport PROJECT_ROOT=%q\n[ "$1" = runme ] && shift\nsource %q\nrunme_main "$@"\n' "$TMPP" "$LIB" > "$FW"
    chmod +x "$FW"
    D="$TMPP/.context/runme/fake"
    mkdir -p "$D"
    LOG="$D/run.log"
}

teardown() { rm -rf "$TMPP"; }

@test "--until start returns 0 at START and prints the START line, with no EXIT in the log" {
    printf '10:00:00 RUNME START fake 2026-10-20T10:00:00Z user=op host=h\n10:00:01 RUNME STEP 1/1\n' > "$LOG"
    run timeout 10 "$FW" runme watch fake --until start --timeout 6
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "runme watch: fake started"
    echo "$output" | grep -q "RUNME START fake 2026-10-20T10:00:00Z"
    ! echo "$output" | grep -q "finished" || false
    # the run is not reported yet: the watch record stays for the exit watch / pending
    [ -f "$D/watch.json" ]
}

@test "--until start waits for START to appear, then returns" {
    : > "$LOG"
    ( sleep 3; echo '10:00:00 RUNME START fake 2026-10-20T10:00:00Z' >> "$LOG" ) &
    run timeout 20 "$FW" runme watch fake --until start --timeout 15
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "RUNME START fake"
}

@test "--until start times out with 124 when nothing starts" {
    run timeout 20 "$FW" runme watch fake --until start --timeout 2
    [ "$status" -eq 124 ]
}

@test "default (no --until) still waits for EXIT: times out 124 on a START-only log" {
    printf '10:00:00 RUNME START fake\n' > "$LOG"
    run timeout 20 "$FW" runme watch fake --timeout 2
    [ "$status" -eq 124 ]
    echo "$output" | grep -q "still running"
}

@test "--until exit returns the script's exit code once EXIT is logged" {
    printf '10:00:00 RUNME START fake\n10:00:01 RUNME EXIT 3\n' > "$LOG"
    run timeout 20 "$FW" runme watch fake --until exit --timeout 6
    [ "$status" -eq 3 ]
    echo "$output" | grep -q "finished (exit 3)"
}

@test "an unknown or missing --until value is refused with exit 2" {
    run "$FW" runme watch fake --until middle
    [ "$status" -eq 2 ]
    run "$FW" runme watch fake --until
    [ "$status" -eq 2 ]
}

@test "watch --help documents --until start|exit" {
    run "$FW" runme watch --help
    [ "$status" -eq 0 ]
    echo "$output" | grep -q -- "--until start|exit"
}
