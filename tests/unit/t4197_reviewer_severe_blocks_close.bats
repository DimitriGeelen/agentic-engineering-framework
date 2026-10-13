#!/usr/bin/env bats
# T-4197 — a severe, deterministic reviewer finding BLOCKS --status work-completed.
#
# Origin: 832 OBS-454 (their T-1150). static_scan.py computes FAIL on a severe
# finding, but update-task.sh ran it "non-blocking" with `|| true`, so a task
# whose Verification was `true` closed with a FAIL verdict written into it.
# Operator ruling 2026-10-13 (2b): block on severe + deterministic findings only;
# everything else stays advisory. Override: --skip-reviewer-severe "reason" /
# FW_SKIP_REVIEWER_SEVERE=1, logged Tier-2, operator-only under CLAUDECODE=1.
# A reviewer that crashes fails OPEN, audibly (WARNING on the close output).

load ../test_helper

UPDATE_TASK="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    unset CLAUDECODE FW_SKIP_REVIEWER_SEVERE FW_REVIEWER_DISABLED FW_REVIEWER_PYTHON
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" \
       "$PROJECT_ROOT/.tasks/templates/default.md" 2>/dev/null || \
       echo "# template" > "$PROJECT_ROOT/.tasks/templates/default.md"
    LOG="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# $1 id, $2 verification line. The verification line lands on file line 23.
_task() {
    local id="$1" verif="$2"
    cat > "$PROJECT_ROOT/.tasks/active/${id}-severe-fixture.md" <<EOF
---
id: $id
name: "Severe fixture"
description: "T-4197 fixture"
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
created: 2026-10-13T00:00:00Z
last_update: 2026-10-13T00:00:00Z
date_finished: null
---

# $id: Severe fixture

## Acceptance Criteria

### Agent
- [x] The one criterion

## Verification
$verif

## Recommendation

**Recommendation:** GO

**Rationale:** fixture.
EOF
}

_closed() { [ -n "$(find "$PROJECT_ROOT/.tasks/completed" -name "$1-*.md")" ]; }

@test "severe deterministic finding (tautological verification) blocks the close" {
    _task T-9801 "true"
    run "$UPDATE_TASK" T-9801 --status work-completed
    [ "$status" -ne 0 ]
    run _closed T-9801
    [ "$status" -ne 0 ]
}

@test "block message names the finding, the file:line and both overrides" {
    _task T-9802 "true"
    run "$UPDATE_TASK" T-9802 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"tautology"* ]]
    [[ "$output" == *".tasks/active/T-9802-severe-fixture.md:23"* ]]
    [[ "$output" == *"--skip-reviewer-severe"* ]]
    [[ "$output" == *"FW_SKIP_REVIEWER_SEVERE=1"* ]]
}

@test "control: a non-tautological verification closes (no severe finding)" {
    _task T-9803 'test -d /'
    run "$UPDATE_TASK" T-9803 --status work-completed
    [ "$status" -eq 0 ]
    _closed T-9803
}

@test "non-severe finding stays advisory (CONCERN verdict, close proceeds)" {
    _task T-9804 'ls / | grep -q tmp'
    run "$UPDATE_TASK" T-9804 --status work-completed
    [ "$status" -eq 0 ]
    _closed T-9804
    [[ "$output" == *"Overall:** CONCERN"* ]]
}

@test "operator override with a reason closes and logs Tier-2" {
    _task T-9805 "true"
    run "$UPDATE_TASK" T-9805 --status work-completed --skip-reviewer-severe "fixture is deliberately tautological"
    [ "$status" -eq 0 ]
    _closed T-9805
    grep -q "flag: '--skip-reviewer-severe'" "$LOG"
    grep -q "reason: 'fixture is deliberately tautological'" "$LOG"
}

@test "override without a reason is refused" {
    _task T-9806 "true"
    run "$UPDATE_TASK" T-9806 --status work-completed --skip-reviewer-severe
    [ "$status" -ne 0 ]
    [[ "$output" == *"needs a reason"* ]]
    run _closed T-9806
    [ "$status" -ne 0 ]
}

@test "agent (CLAUDECODE=1): --skip-reviewer-severe is refused" {
    _task T-9807 "true"
    CLAUDECODE=1 run "$UPDATE_TASK" T-9807 --status work-completed --skip-reviewer-severe "x"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refused in an agent session"* ]]
    run _closed T-9807
    [ "$status" -ne 0 ]
}

@test "agent with --i-am-human: override allowed and the log says so" {
    _task T-9808 "true"
    CLAUDECODE=1 run "$UPDATE_TASK" T-9808 --status work-completed --skip-reviewer-severe --reason "operator" --i-am-human
    [ "$status" -eq 0 ]
    _closed T-9808
    grep -q "i-am-human under CLAUDECODE=1" "$LOG"
}

@test "FW_SKIP_REVIEWER_SEVERE=1 (operator): closes and logs Tier-2" {
    _task T-9809 "true"
    FW_SKIP_REVIEWER_SEVERE=1 run "$UPDATE_TASK" T-9809 --status work-completed
    [ "$status" -eq 0 ]
    _closed T-9809
    grep -q "flag: 'FW_SKIP_REVIEWER_SEVERE'" "$LOG"
}

@test "FW_SKIP_REVIEWER_SEVERE=1 under CLAUDECODE=1 is refused" {
    _task T-9810 "true"
    CLAUDECODE=1 FW_SKIP_REVIEWER_SEVERE=1 run "$UPDATE_TASK" T-9810 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"refused in an agent session"* ]]
    run _closed T-9810
    [ "$status" -ne 0 ]
}

@test "FW_REVIEWER_DISABLED=1 does not disable the severe gate" {
    _task T-9811 "true"
    FW_REVIEWER_DISABLED=1 run "$UPDATE_TASK" T-9811 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"tautology"* ]]
}

@test "reviewer crash fails OPEN, audibly" {
    _task T-9812 "true"
    printf '#!/bin/sh\necho "boom" >&2\nexit 3\n' > "$TEST_TEMP_DIR/crashpy"
    chmod +x "$TEST_TEMP_DIR/crashpy"
    FW_REVIEWER_PYTHON="$TEST_TEMP_DIR/crashpy" run "$UPDATE_TASK" T-9812 --status work-completed
    [ "$status" -eq 0 ]
    _closed T-9812
    [[ "$output" == *"WARNING: reviewer severe-finding gate could not run"* ]]
}
