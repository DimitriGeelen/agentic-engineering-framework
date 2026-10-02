#!/usr/bin/env bats
# T-3580 round 7 (codex MEDIUM-3): `fw termlink cleanup` must not delete a REVIEW worker's dir
# between `exit_code` and `finalised` — run.sh writes exit_code first, then signs the completion.
# Sandbox only: DISPATCH_DIR is under $BATS_TEST_TMPDIR; the only process signalled is the fake
# runtime this test spawns.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
TERMLINK_SH="$FRAMEWORK_ROOT/agents/termlink/termlink.sh"

setup() {
    DD="$BATS_TEST_TMPDIR/tl-dispatch"
    mkdir -p "$DD"
    RT_PID=""
}

teardown() {
    [ -n "$RT_PID" ] && kill -KILL "$RT_PID" 2>/dev/null || true
}

run_cleanup() {
    run env FW_DISPATCH_DIR="$DD" bash -c "source '$TERMLINK_SH' >/dev/null 2>&1; [ \"\$DISPATCH_DIR\" = '$DD' ] || exit 99; cmd_cleanup --yes"  # T-3716: consent required since T-3651
}

# A review runtime paused in the window: the worker has exited (exit_code written), the runtime
# (a process whose args hold <wdir>/run.sh) is still alive and has not written `finalised`.
paused_review_runtime() {
    local w="$DD/$1"
    mkdir -p "$w"
    : > "$w/finalise_required"
    echo 0 > "$w/exit_code"
    echo '{"type":"result"}' > "$w/result.jsonl"
    python3 -c 'import time; time.sleep(300)' "$w/run.sh" &
    RT_PID=$!
    sleep 0.3
}

@test "a review runtime paused between exit_code and finalised is kept" {
    paused_review_runtime rv-paused
    run_cleanup
    [ "$status" -eq 0 ]
    [ -d "$DD/rv-paused" ]
    [ -f "$DD/rv-paused/result.jsonl" ]
    [[ "$output" == *"not finalised yet"* ]]
}

@test "a review worker whose runtime exited without finalising is kept, not deleted" {
    mkdir -p "$DD/rv-dead"
    : > "$DD/rv-dead/finalise_required"
    echo 0 > "$DD/rv-dead/exit_code"
    run_cleanup
    [ -d "$DD/rv-dead" ]
}

@test "control: once finalised and the runtime has gone, the review dir is removed" {
    paused_review_runtime rv-done
    echo "unsigned:completion-refused" > "$DD/rv-done/finalised"
    kill -KILL "$RT_PID"; wait "$RT_PID" 2>/dev/null || true; RT_PID=""
    run_cleanup
    [ ! -d "$DD/rv-done" ]
}

@test "control: an ordinary finished worker (no finalise_required) is still removed" {
    mkdir -p "$DD/plain" && echo 0 > "$DD/plain/exit_code"
    run_cleanup
    [ ! -d "$DD/plain" ]
}
