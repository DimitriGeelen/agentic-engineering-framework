#!/usr/bin/env bats
# T-4776: the run.sh kill watchdog sent SIGTERM and nothing else. tl-350f6206's claude, blocked
# in a Settings Error dialog, ignored it and was still alive 28 h past its 1800 s timeout;
# `wait` never returned, exit_code was never written, and `fw termlink cleanup` kept calling the
# worker ACTIVE. The watchdog is now one helper (_fw_watchdog): TERM, a grace period, then KILL.
#
# House style (t3440_close_state.bats): blocks are lifted out of the LIVE run.sh template
# between their markers, so editing agents/termlink/termlink.sh moves these assertions.
#
# SAFETY: every fake worker runs under $BATS_TEST_TMPDIR, is tracked in $PIDS_FILE and killed
# in teardown. Nothing touches a real dispatch dir.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SRC="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"

setup() {
    DD="$BATS_TEST_TMPDIR/tl-dispatch"
    WDIR="$DD/w1"
    mkdir -p "$WDIR"
    export PROJECT_ROOT="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJECT_ROOT"
    printf '{\n  "name": "w1",\n  "project": "%s",\n  "timeout": 1\n}\n' "$PROJECT_ROOT" > "$WDIR/meta.json"
    PIDS_FILE="$BATS_TEST_TMPDIR/pids"
    : > "$PIDS_FILE"
}

teardown() {
    local pid
    while read -r pid; do
        [ -n "$pid" ] || continue
        pkill -KILL -P "$pid" 2>/dev/null || true
        kill -KILL "$pid" 2>/dev/null || true
    done < "$PIDS_FILE"
}

extract() {  # <marker-name>
    python3 - "$SRC" "$1" <<'PY'
import sys
lines = open(sys.argv[1]).read().split("\n")
tag = sys.argv[2]
start = [i for i, l in enumerate(lines) if l.startswith("# --- %s (start)" % tag)]
end = [i for i, l in enumerate(lines) if l.startswith("# --- %s (end)" % tag)]
if not start or not end:
    raise SystemExit("%s markers not found in termlink.sh" % tag)
print("\n".join(lines[start[0]:end[0] + 1]))
PY
}

# A mini run.sh: the live watchdog helper, then the same launch/watch/wait/exit_code shape as
# the CLAUDE_PID site. $1 = the worker command. It lives in $WDIR so its argv names the dir,
# like the real run.sh (that is how cleanup finds a worker's processes).
write_runsh() {
    local block
    block=$(extract "T-4776 watchdog") || return 1
    {
        echo '#!/bin/bash'
        echo "WDIR='$WDIR'"
        echo 'TIMEOUT=1'
        echo 'WATCHDOG_KILL_GRACE=1'
        echo "$block"
        echo "$1 &"
        echo 'CLAUDE_PID=$!'
        echo 'echo "$CLAUDE_PID" > "$WDIR/worker.pid"'
        echo '( _fw_watchdog "$CLAUDE_PID" ) &'
        echo 'WATCHDOG_PID=$!'
        echo 'wait "$CLAUDE_PID" 2>/dev/null'
        echo 'EXIT_CODE=$?'
        echo 'kill "$WATCHDOG_PID" 2>/dev/null || true'
        echo 'echo "$EXIT_CODE" > "$WDIR/exit_code"'
    } > "$WDIR/run.sh"
}

# The worker that started this: TERM is ignored (and stays ignored across exec), named claude.
TERM_DEAF="bash -c 'trap \"\" TERM; exec -a claude sleep 300'"

@test "the watchdog block is present in the live run.sh template" {
    run extract "T-4776 watchdog"
    [ "$status" -eq 0 ]
    [[ "$output" == *"_fw_watchdog()"* ]]
    [[ "$output" == *"kill -KILL"* ]]
    [[ "$output" == *'WATCHDOG_KILL_GRACE="${WATCHDOG_KILL_GRACE:-10}"'* ]]
}

@test "all three watchdog sites use the helper; no TERM-only watchdog is left" {
    for v in LOOP_PID HARNESS_PID CLAUDE_PID; do
        grep -qF "( _fw_watchdog \"\$$v\" ) &" "$SRC"
    done
    ! grep -qE 'sleep "\$TIMEOUT" && kill "\$[A-Z_]+_PID"' "$SRC" || false
}

@test "control: the pre-fix TERM-only watchdog leaves a TERM-ignoring worker alive" {
    eval "$TERM_DEAF >/dev/null 2>&1 3>&- &"
    local pid=$!
    echo "$pid" >> "$PIDS_FILE"
    sleep 0.3
    (sleep 1 && kill "$pid" 2>/dev/null && echo "TIMEOUT" >> "$WDIR/stderr.log") >/dev/null 2>&1 3>&- &
    sleep 3
    grep -q '^TIMEOUT$' "$WDIR/stderr.log"
    kill -0 "$pid"
}

@test "a TERM-ignoring worker is SIGKILLed after the grace period; exit_code is written" {
    write_runsh "$TERM_DEAF"
    timeout 30 bash "$WDIR/run.sh" >"$WDIR/run.out" 2>&1 3>&- &
    local rpid=$!
    echo "$rpid" >> "$PIDS_FILE"
    wait "$rpid"
    [ -f "$WDIR/exit_code" ]
    [ "$(cat "$WDIR/exit_code")" -eq 137 ]
    ! kill -0 "$(cat "$WDIR/worker.pid")" 2>/dev/null || false
    [ -f "$WDIR/timed_out" ]
    [ "$(grep -c '^TIMEOUT$' "$WDIR/stderr.log")" -eq 1 ]
    grep -q 'still alive 1s after SIGTERM — sent SIGKILL' "$WDIR/stderr.log"
}

@test "a worker that dies on TERM gets no SIGKILL" {
    write_runsh "sleep 300"
    timeout 30 bash "$WDIR/run.sh" >"$WDIR/run.out" 2>&1 3>&-
    [ "$(cat "$WDIR/exit_code")" -eq 143 ]
    [ -f "$WDIR/timed_out" ]
    grep -q '^TIMEOUT$' "$WDIR/stderr.log"
    ! grep -q 'SIGKILL' "$WDIR/stderr.log" || false
}

@test "a worker that finishes before the timeout is untouched" {
    write_runsh "true"
    timeout 30 bash "$WDIR/run.sh" >"$WDIR/run.out" 2>&1 3>&-
    [ "$(cat "$WDIR/exit_code")" -eq 0 ]
    [ ! -e "$WDIR/timed_out" ]
    [ ! -e "$WDIR/stderr.log" ] || ! grep -q TIMEOUT "$WDIR/stderr.log" || false
}

@test "after a timeout the worker is no longer ACTIVE in fw termlink cleanup --dry-run" {
    write_runsh "$TERM_DEAF"
    timeout 30 bash "$WDIR/run.sh" >"$WDIR/run.out" 2>&1 3>&-
    [ -f "$WDIR/exit_code" ]
    run env FW_DISPATCH_DIR="$DD" bash -c "source '$SRC' >/dev/null 2>&1; [ \"\$DISPATCH_DIR\" = '$DD' ] || exit 99; cmd_cleanup --dry-run"
    [ "$status" -ne 99 ]
    [[ "$output" != *"ACTIVE"*"w1"* ]]
}

@test "close_state is recorded as timeout when the watchdog fired" {
    local block
    block=$(extract "T-3440 close-state check") || return 1
    mkdir -p "$PROJECT_ROOT/.tasks/active"
    : > "$WDIR/timed_out"
    {
        echo '#!/bin/bash'
        echo "PROJECT_DIR='$PROJECT_ROOT'"
        echo "WDIR='$WDIR'"
        echo 'EXIT_CODE=137'
        echo "$block"
    } > "$BATS_TEST_TMPDIR/cs.sh"
    bash "$BATS_TEST_TMPDIR/cs.sh"
    [ "$(cat "$WDIR/close_state")" = "timeout" ]
}
