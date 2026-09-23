#!/usr/bin/env bats
# T-3440 — a dispatched worker's exit 0 does not mean its task was closed.
#
# Three `claude -p` workers on 2026-09-22 (T-3211, T-3431/T-3435, T-3433) ended
# their turn waiting on a run_in_background job and exited. The work was done;
# the task was left started-work; the driver recorded a success. These tests pin
# the post-step that now decides close_state, and the preamble rule that stops a
# worker backgrounding a job in the first place.
#
# House style (t3346_termlink_exit_marker.bats): the close-state block is lifted
# out of the LIVE run.sh template between its markers, so editing
# agents/termlink/termlink.sh moves these assertions rather than orphaning them.

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    SRC="${BATS_TEST_DIRNAME}/../../agents/termlink/termlink.sh"
    PREAMBLE="${BATS_TEST_DIRNAME}/../../agents/dispatch/preamble.md"
    PROJ="$TEST_TEMP_DIR/proj"
    WDIR="$TEST_TEMP_DIR/wdir"
    mkdir -p "$PROJ/.tasks/active" "$PROJ/.tasks/completed" "$WDIR"
    printf '{"name":"w1","status":"done","exit_code":0}\n' > "$WDIR/meta.json"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

extract_block() {
    python3 - "$SRC" <<'PY'
import sys
lines = open(sys.argv[1]).read().split("\n")
start = [i for i, l in enumerate(lines)
         if l.startswith("# --- T-3440 close-state check (start)")]
end = [i for i, l in enumerate(lines)
       if l.startswith("# --- T-3440 close-state check (end)")]
if not start or not end:
    raise SystemExit("T-3440 close-state markers not found in termlink.sh")
print("\n".join(lines[start[0]:end[0] + 1]))
PY
}

# Stub run.sh: the real block plus only the variables run.sh would have set by
# the time the exit code is known. No claude, no termlink, no dispatch.
run_stub() {
    local exit_code="$1" block
    block=$(extract_block) || return 1
    {
        echo '#!/bin/bash'
        echo "PROJECT_DIR='$PROJ'"
        echo "WDIR='$WDIR'"
        echo "EXIT_CODE=$exit_code"
        echo "$block"
    } > "$TEST_TEMP_DIR/run.sh"
    bash "$TEST_TEMP_DIR/run.sh"
}

write_task() {  # <active|completed> <task-id> <status>
    cat > "$PROJ/.tasks/$1/$2-fixture-task.md" <<EOF
---
id: $2
name: "fixture"
status: $3
workflow_type: build
---
EOF
}

meta_field() {  # <field>
    python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2],'<missing>'))" \
        "$WDIR/meta.json" "$1"
}

@test "close-state block is present in the live run.sh template" {
    run extract_block
    [ "$status" -eq 0 ]
    [[ "$output" == *"close_state"* ]]
    [[ "$output" == *"is still started-work — close not run"* ]]
}

@test "exit 0 with the task still started-work in active/ → incomplete" {
    echo "T-9001" > "$WDIR/task"
    write_task active T-9001 started-work

    run run_stub 0
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING: worker exited 0 but T-9001 is still started-work — close not run"* ]]
    [ "$(cat "$WDIR/close_state")" = "incomplete" ]
    [ "$(meta_field close_state)" = "incomplete" ]
    [ "$(meta_field close_state_task)" = "T-9001" ]
}

@test "the same fixture with the task moved to completed/ → closed, no warning" {
    echo "T-9001" > "$WDIR/task"
    write_task completed T-9001 work-completed

    run run_stub 0
    [ "$status" -eq 0 ]
    [ "$(cat "$WDIR/close_state")" = "closed" ]
    [ "$(meta_field close_state)" = "closed" ]
    run grep -q "WARNING" <<< "$output"
    [ "$status" -eq 1 ]
}

@test "partial-complete (work-completed still in active/) → closed" {
    echo "T-9002" > "$WDIR/task"
    write_task active T-9002 work-completed

    run run_stub 0
    [ "$status" -eq 0 ]
    [ "$(cat "$WDIR/close_state")" = "closed" ]
}

@test "meta.json rewrite preserves the fields the post-step already wrote" {
    echo "T-9001" > "$WDIR/task"
    write_task active T-9001 started-work

    run run_stub 0
    [ "$status" -eq 0 ]
    [ "$(meta_field name)" = "w1" ]
    [ "$(meta_field status)" = "done" ]
}

@test "no task file for the dispatched id → n/a" {
    echo "T-9404" > "$WDIR/task"

    run run_stub 0
    [ "$status" -eq 0 ]
    [ "$(cat "$WDIR/close_state")" = "n/a" ]
}

@test "no task dispatched at all → n/a" {
    run run_stub 0
    [ "$status" -eq 0 ]
    [ "$(cat "$WDIR/close_state")" = "n/a" ]
}

@test "a non-zero exit is not a close verdict → n/a, no warning" {
    echo "T-9001" > "$WDIR/task"
    write_task active T-9001 started-work

    run run_stub 1
    [ "$status" -eq 0 ]
    [ "$(cat "$WDIR/close_state")" = "n/a" ]
    run grep -q "WARNING" <<< "$output"
    [ "$status" -eq 1 ]
}

@test "a status the rule says nothing about (captured) → n/a" {
    echo "T-9003" > "$WDIR/task"
    write_task active T-9003 captured

    run run_stub 0
    [ "$status" -eq 0 ]
    [ "$(cat "$WDIR/close_state")" = "n/a" ]
}

@test "preamble: the worker rule forbids run_in_background and names the reason" {
    run grep -q "Never background a job — a worker has no next turn" "$PREAMBLE"
    [ "$status" -eq 0 ]
    run grep -q 'NEVER use `run_in_background: true`' "$PREAMBLE"
    [ "$status" -eq 0 ]
    run grep -q "inline, under \`timeout\`" "$PREAMBLE"
    [ "$status" -eq 0 ]
    run grep -q "Finish every unit to its close in the same turn" "$PREAMBLE"
    [ "$status" -eq 0 ]
}

@test "preamble: the old unscoped background line is gone" {
    run grep -q 'Use `run_in_background: true` for any agent expected to produce' "$PREAMBLE"
    [ "$status" -eq 1 ]
}

@test "preamble: the orchestrator rules declare they are for parent sessions" {
    run grep -q "Scope: a parent session using the Task tool" "$PREAMBLE"
    [ "$status" -eq 0 ]
    run grep -q "parent sessions using the Task tool" "$PREAMBLE"
    [ "$status" -eq 0 ]
}

# --- surfacing (AC3). cmd_result is used rather than cmd_status because
# cmd_status calls ensure_termlink, and a skip on a missing binary would report
# `ok` while measuring nothing (T-3217).

result_with_close_state() {  # <close_state> <task-id>
    local dd="$TEST_TEMP_DIR/dispatch"
    mkdir -p "$dd/w1"
    echo 0 > "$dd/w1/exit_code"
    echo "$2" > "$dd/w1/task"
    echo "$1" > "$dd/w1/close_state"
    echo "worker body" > "$dd/w1/result.md"
    bash -c "source '$SRC'; DISPATCH_DIR='$dd'; cmd_result w1" 2>&1
}

@test "fw termlink result leads with the incomplete close and names the task" {
    run result_with_close_state incomplete T-9001
    [ "$status" -eq 0 ]
    [[ "$output" == *"close_state: incomplete"* ]]
    [[ "$output" == *"T-9001"* ]]
    [[ "$output" == *"worker body"* ]]
}

@test "fw termlink result stays quiet when there is nothing to assert (n/a)" {
    run result_with_close_state "n/a" T-9001
    [ "$status" -eq 0 ]
    [[ "$output" == *"worker body"* ]]
    run grep -q "close_state" <<< "$output"
    [ "$status" -eq 1 ]
}
