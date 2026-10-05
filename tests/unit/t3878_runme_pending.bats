#!/usr/bin/env bats
# T-3878: a `fw runme watch` dies with the session that armed it, so an
# operator's run after an agent restart went unobserved (832 T-1050; here the
# pre-reboot waits ended "stopped"). The watch now records who armed it, and
# `fw runme pending` names WATCH LOST / RUN IN FLIGHT / RUN ENDED WITHOUT RECORD.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR/proj"
    R="$PROJECT_ROOT/.context/runme"
    mkdir -p "$R"
    source "${BATS_TEST_DIRNAME}/../../lib/runme.sh"
    BG=""
}

teardown() {
    [ -n "$BG" ] && kill $BG 2>/dev/null || true
    rm -rf "$TEST_TEMP_DIR"
}

_runme() {   # _runme <name> <log-content>
    mkdir -p "$R/$1"; printf '#!/bin/bash\ntrue\n' > "$R/$1/runme.sh"
    printf '%b' "$2" > "$R/$1/run.log"
}
_dead_pid() { bash -c 'exit 0' & local p=$!; wait $p; echo $p; }

@test "t3878: clean — finished runs report nothing pending, and drop a stale watch record" {
    _runme done "RUNME START done\nRUNME EXIT 0\n"
    echo '{"watch_pid": 1, "arming_claude_pid": 1, "armed_at": "x"}' > "$R/done/watch.json"
    run runme_pending
    [ "$output" = "runme: nothing pending" ]
    [ ! -f "$R/done/watch.json" ]
}

@test "t3878: WATCH LOST — not yet run, the arming session is gone" {
    _runme upgrade ""
    d=$(_dead_pid)
    printf '{"watch_pid": %s, "arming_claude_pid": %s, "armed_at": "x"}\n' "$d" "$d" > "$R/upgrade/watch.json"
    run runme_pending
    [[ "$output" == *"WATCH LOST  upgrade"*"re-arm: fw runme watch upgrade"* ]]
}

@test "t3878: a live watch armed by a live session is NOT reported" {
    _runme upgrade ""
    sleep 60 & BG=$!
    printf '{"watch_pid": %s, "arming_claude_pid": %s, "armed_at": "x"}\n' "$BG" "$BG" > "$R/upgrade/watch.json"
    run runme_pending
    [ "$output" = "runme: nothing pending" ]
}

@test "t3878: RUN IN FLIGHT — started, no EXIT, runme.sh still running" {
    _runme fly "RUNME START fly\n"
    bash -c "exec -a '$R/fly/runme.sh' sleep 60" & BG=$!
    sleep 0.2
    run runme_pending
    [[ "$output" == *"RUN IN FLIGHT  fly"* ]]
}

@test "t3878: RUN ENDED WITHOUT RECORD — started, no EXIT, nothing runs it" {
    _runme gone "RUNME START gone\n"
    run runme_pending
    [[ "$output" == *"RUN ENDED WITHOUT RECORD  gone"* ]]
}

@test "t3878: watch writes the record, removes it on EXIT, keeps it on timeout" {
    _runme ok "RUNME START ok\nRUNME EXIT 0\n"
    run runme_watch ok --timeout 4
    [ "$status" -eq 0 ]
    [ ! -f "$R/ok/watch.json" ]
    mkdir -p "$R/never"; printf '#!/bin/bash\n' > "$R/never/runme.sh"
    run runme_watch never --timeout 2
    [ "$status" -eq 124 ]
    grep -q '"watch_pid"' "$R/never/watch.json"
    grep -q '"arming_claude_pid"' "$R/never/watch.json"
}

@test "t3878: the session-start hook carries the findings" {
    f="${BATS_TEST_DIRNAME}/../../agents/context/post-compact-resume.sh"
    grep -q 'runme_pending' "$f"
    grep -q 'Operator Runmes Needing Attention (T-3878)' "$f"
}
