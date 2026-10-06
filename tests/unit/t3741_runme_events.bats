#!/usr/bin/env bats
# T-3741 — a runme script announces itself; a watch outlives a late operator.
#
# 2026-10-06: two watches gave up after the old 1800 s default because the operator ran the
# line later, so the run reached nobody. Now every generated runme.sh writes START / STEP k/n /
# EXIT rc / STOPPED SIG to run.log AND to .context/runme/events.jsonl, and the default watch
# window is a day. Same driver pattern as t3675_runme.bats (lib/runme.sh on a temp project).

setup() {
    LIB="$BATS_TEST_DIRNAME/../../lib/runme.sh"
    TMPP="$(mktemp -d)"
    FW="$BATS_TEST_TMPDIR/fw-runme"
    printf '#!/bin/bash\nexport PROJECT_ROOT=%q\n[ "$1" = runme ] && shift\nsource %q\nrunme_main "$@"\n' "$TMPP" "$LIB" > "$FW"
    chmod +x "$FW"
    EV="$TMPP/.context/runme/events.jsonl"
}

teardown() { rm -rf "$TMPP"; }

_events() {   # name -> "event step rc signal" per line
    python3 -c 'import json,sys
for l in open(sys.argv[1]):
    d=json.loads(l)
    if d["name"]==sys.argv[2]: print(d["event"], d["step"] or "-", d["rc"] or "-", d["signal"] or "-")' "$EV" "$1"
}

@test "T-3741: a 2-step success emits start, step 1/2, step 2/2, exit 0" {
    "$FW" runme new ok -- 'echo one' 'echo two' >/dev/null
    bash "$TMPP/.context/runme/ok/runme.sh" >/dev/null 2>&1
    sleep 0.5
    [ "$(_events ok | tr '\n' '|')" = "start - - -|step 1/2 - -|step 2/2 - -|exit - 0 -|" ]
    grep -q "RUNME STEP 2/2" "$TMPP/.context/runme/ok/run.log"
}

@test "T-3741: a failing step stops the run at that step and records exit 1" {
    "$FW" runme new bad -- 'false' 'echo never' >/dev/null
    run bash "$TMPP/.context/runme/bad/runme.sh"
    sleep 0.5
    [ "$(_events bad | tr '\n' '|')" = "start - - -|step 1/2 - -|exit - 1 -|" ]
}

@test "T-3741: SIGTERM records STOPPED TERM and watch returns 143 naming it" {
    "$FW" runme new longrun -- 'sleep 30' >/dev/null
    # Own process group, signalled as a whole — what a terminal's Ctrl-C / hangup does.
    setsid bash "$TMPP/.context/runme/longrun/runme.sh" >/dev/null 2>&1 &
    pid=$!
    for _ in $(seq 1 50); do grep -q "RUNME STEP 1/1" "$TMPP/.context/runme/longrun/run.log" 2>/dev/null && break; sleep 0.1; done
    kill -TERM -- "-$pid"
    wait "$pid" || true
    sleep 0.5
    _events longrun | grep -qx "stopped - 143 TERM"
    run "$FW" runme watch longrun --timeout 5
    [ "$status" -eq 143 ]
    [[ "$output" == *"STOPPED by SIGTERM"* ]]
}

@test "T-3741/control: a finished run's watch reports 'finished' with the script's exit code" {
    "$FW" runme new fine -- 'true' >/dev/null
    bash "$TMPP/.context/runme/fine/runme.sh" >/dev/null 2>&1
    sleep 0.5
    run "$FW" runme watch fine --timeout 5
    [ "$status" -eq 0 ]
    [[ "$output" == *"fine finished (exit 0)"* ]]
}

@test "T-3741: pending reports an interrupted run whose watch never reported it" {
    "$FW" runme new cut -- 'sleep 30' >/dev/null
    printf '{"watch_pid": 999999, "arming_claude_pid": null, "armed_at": "x"}\n' > "$TMPP/.context/runme/cut/watch.json"
    setsid bash "$TMPP/.context/runme/cut/runme.sh" >/dev/null 2>&1 &
    pid=$!
    for _ in $(seq 1 50); do grep -q "RUNME STEP 1/1" "$TMPP/.context/runme/cut/run.log" 2>/dev/null && break; sleep 0.1; done
    # HUP (terminal closed), not INT: a background job of a non-interactive shell (bats)
    # starts with SIGINT ignored, and bash cannot trap a signal ignored at entry. In the
    # operator's terminal Ctrl-C reaches the foreground script normally.
    kill -HUP -- "-$pid"; wait "$pid" || true; sleep 0.5
    run "$FW" runme pending
    [[ "$output" == *"RUN STOPPED  cut"*"SIGHUP"* ]]
}

@test "T-3741: the default watch window is at least a day" {
    grep -qE 'FW_RUNME_WATCH_TIMEOUT:-86400' "$LIB"
}
