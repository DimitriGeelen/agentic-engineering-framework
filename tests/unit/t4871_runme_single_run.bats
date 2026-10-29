#!/usr/bin/env bats
# T-4871 (ring20-dashboard msgs 4c7cd097, c20890c2): a second start of the same runme
# emptied the running run's log and appended to it in parallel, so the first run's
# record was lost or ended with the second run's lines. A runme now takes a lock
# before it touches run.log and refuses a second concurrent start.

setup() {
    LIB="$BATS_TEST_DIRNAME/../../lib/runme.sh"
    TMPP="$(mktemp -d)"
    FW="$BATS_TEST_TMPDIR/fw-runme"
    printf '#!/bin/bash\nexport PROJECT_ROOT=%q\n[ "$1" = runme ] && shift\nsource %q\nrunme_main "$@"\n' "$TMPP" "$LIB" > "$FW"
    chmod +x "$FW"
    D="$TMPP/.context/runme"
}

teardown() {
    [ -n "${BG:-}" ] && kill "$BG" 2>/dev/null; touch "$TMPP/go" 2>/dev/null
    wait 2>/dev/null || true
    rm -rf "$TMPP"
}

_new() { local name="$1"; shift; "$FW" runme new "$name" -- "$@" >/dev/null; }

_wait_for() {   # <file> <pattern>
    local i=0
    until grep -q "$2" "$1" 2>/dev/null; do i=$((i + 1)); [ "$i" -lt 100 ] || return 1; sleep 0.1; done
}

@test "a second start while the first runs is refused; the first log stays intact" {
    _new slow 'echo first-body' "until [ -f '$TMPP/go' ]; do sleep 0.1; done" 'echo first-done'
    bash "$D/slow/runme.sh" >/dev/null 2>&1 3>&- & BG=$!
    _wait_for "$D/slow/run.log" "first-body"
    starts_before=$(grep -c '"event":"start"' "$D/events.jsonl")

    run bash "$D/slow/runme.sh"
    [ "$status" -eq 75 ]
    [[ "$output" == *"already running (pid $BG)"* ]]
    [[ "$output" == *"$D/slow/run.log"* ]]
    grep -q "first-body" "$D/slow/run.log"           # not emptied
    [ "$(grep -c '"event":"start"' "$D/events.jsonl")" -eq "$starts_before" ]

    touch "$TMPP/go"; wait "$BG"; BG=""
    sleep 0.5
    grep -q "first-done" "$D/slow/run.log"
    [ "$(grep -c 'RUNME START' "$D/slow/run.log")" -eq 1 ]
    tail -1 "$D/slow/run.log" | grep -q "RUNME EXIT 0"
    [ ! -e "$D/slow/.running" ]
}

@test "sequential re-runs work: the lock is released at exit" {
    _new again 'echo hi'
    run bash "$D/again/runme.sh"; [ "$status" -eq 0 ]
    [ ! -e "$D/again/.running" ]
    run bash "$D/again/runme.sh"; [ "$status" -eq 0 ]
    sleep 0.5
    grep -q "RUNME EXIT 0" "$D/again/run.log"
}

@test "a failing step still releases the lock" {
    _new fails 'false'
    run bash "$D/fails/runme.sh"
    [ "$status" -ne 0 ]
    [ ! -e "$D/fails/.running" ]
}

@test "a signal stop releases the lock" {
    _new stopme "until [ -f '$TMPP/go' ]; do sleep 0.1; done"
    bash "$D/stopme/runme.sh" >/dev/null 2>&1 3>&- & BG=$!
    _wait_for "$D/stopme/run.log" "RUNME STEP 1/1"
    # TERM reaches only the parent here (a terminal's Ctrl-C reaches the whole group);
    # bash runs the trap once its foreground subshell returns, so let that step end.
    kill -TERM "$BG"; sleep 0.3; touch "$TMPP/go"; wait "$BG" 2>/dev/null || true; BG=""
    sleep 0.5
    grep -q "RUNME STOPPED TERM" "$D/stopme/run.log"
    [ ! -e "$D/stopme/.running" ]
}

@test "a stale lock (pid gone) is taken over with a note" {
    _new stale 'echo ran'
    mkdir "$D/stale/.running"
    bash -c 'exit 0' & dead=$!; wait "$dead"
    echo "$dead" > "$D/stale/.running/pid"
    run bash "$D/stale/runme.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"taking over a stale lock (pid $dead is gone)"* ]]
    sleep 0.5
    grep -q " ran$" "$D/stale/run.log"
    [ ! -e "$D/stale/.running" ]
}
