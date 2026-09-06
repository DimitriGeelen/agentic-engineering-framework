#!/usr/bin/env bats
# T-3306 (OBS-372) — a close must FAIL FAST, never deadlock, when its own
# P-011 verification invokes `fw task update` on the task under close.
#
# The class: update-task.sh holds the per-task keylock (T-587) for the whole
# close; a nested update on the same id used to block forever on that lock —
# measured at 3h+ of silent hang before the tree was killed (T-1719's
# happiness suite, 2026-09-06). Two layers ship and both are pinned here:
#
#   1. GUARD ENV — the close exports FW_TASK_UPDATE_IN_CLOSE=<id> around
#      run_verification_commands; a nested same-id update refuses before
#      touching the keylock, naming the remedy. Different-id updates proceed
#      (that is the sanctioned fixture pattern, t1719_happiness_signal.bats).
#
#   2. BOUNDED KEYLOCK — keylock_acquire gets a 120s timeout, so even a
#      reentry path the env didn't reach (detached child) ends in a loud
#      error instead of an unbounded hang.
#
# All close runs here operate on an ISOLATED TASKS_DIR/CONTEXT_DIR so the
# live corpus is never mutated; nested `update-task.sh` invocations inherit
# the redirection via exported env.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    UPDATE="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"
    export TASKS_DIR="$BATS_TEST_TMPDIR/tasks"
    export CONTEXT_DIR="$BATS_TEST_TMPDIR/context"
    mkdir -p "$TASKS_DIR/active" "$TASKS_DIR/completed" "$CONTEXT_DIR/working"
}

teardown() {
    unset TASKS_DIR CONTEXT_DIR FW_TASK_UPDATE_IN_CLOSE
}

_make_fixture() {
    # $1 = task id, $2 = verification line
    cat > "$TASKS_DIR/active/$1-reentry-fixture.md" <<EOF
---
id: $1
name: "reentry guard fixture $1"
description: fixture
status: started-work
workflow_type: build
horizon: now
owner: agent
tags: []
components: []
related_tasks: []
created: 2026-09-06T00:00:00Z
last_update: 2026-09-06T00:00:00Z
---

## Acceptance Criteria

### Agent
- [x] fixture criterion

## Verification

$2
EOF
}

@test "t3306: nested same-id update under the close-guard env refuses fast" {
    _make_fixture "T-9997" "true"
    export FW_TASK_UPDATE_IN_CLOSE="T-9997"
    local t0=$SECONDS
    run bash "$UPDATE" T-9997 --happiness +1
    [ "$status" -ne 0 ]
    [[ "$output" == *"reentry"* ]]
    [[ "$output" == *"fixture task"* ]]
    [ $((SECONDS - t0)) -lt 10 ]
}

@test "t3306: nested DIFFERENT-id update under the guard env proceeds" {
    _make_fixture "T-9997" "true"
    _make_fixture "T-9996" "true"
    export FW_TASK_UPDATE_IN_CLOSE="T-9997"
    run bash "$UPDATE" T-9996 --happiness +1
    [ "$status" -eq 0 ]
}

@test "t3306: end-to-end — a close whose verification updates the SAME task fails fast, not forever" {
    _make_fixture "T-9997" "bash '$UPDATE' T-9997 --happiness +1"
    local t0=$SECONDS
    run timeout 90 bash "$UPDATE" T-9997 --status work-completed
    [ "$status" -ne 0 ]
    [ "$status" -ne 124 ]   # a timeout kill would mean the hang is back
    [[ "$output" == *"verification"* || "$output" == *"Verification"* ]]
    [ $((SECONDS - t0)) -lt 60 ]
    # the task must NOT have archived
    [ -f "$TASKS_DIR/active/T-9997-reentry-fixture.md" ]
}

@test "t3306: control — a close whose verification updates a DIFFERENT task completes" {
    # The verification subshell deliberately unsets TASKS_DIR/CONTEXT_DIR
    # (T-739, update-task.sh:1232) so nested commands re-derive from
    # PROJECT_ROOT — the fixture line must re-export the isolated dirs itself
    # or the nested update would look in the LIVE corpus.
    _make_fixture "T-9997" "TASKS_DIR='$TASKS_DIR' CONTEXT_DIR='$CONTEXT_DIR' bash '$UPDATE' T-9996 --happiness +1"
    _make_fixture "T-9996" "true"
    run timeout 90 bash "$UPDATE" T-9997 --status work-completed
    [ "$status" -eq 0 ]
    [ -f "$TASKS_DIR/completed/T-9997-reentry-fixture.md" ]
}

@test "t3306: keylock acquisition in update-task.sh is bounded, not blocking-forever" {
    run grep -c 'keylock_acquire "\$TASK_ID" 120' "$UPDATE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
    # the unbounded form must be gone
    run grep -cE 'keylock_acquire "\$TASK_ID"$' "$UPDATE"
    [[ "$output" == "0" ]]
}

@test "t3306: the close exports the guard env around its verification run" {
    run grep -c 'export FW_TASK_UPDATE_IN_CLOSE="\$TASK_ID"' "$UPDATE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}
