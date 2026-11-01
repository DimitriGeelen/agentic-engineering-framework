#!/usr/bin/env bats
# T-4969 — the operator hands a human-owned task to the agent (operator 2026-11-01, after the
# external review in docs/reports/T-4969-ownership-ruleset-review.md).
#
# Origin: 055's operator ran the command `fw note promote` printed for five tasks and R-033
# refused all five; Watchtower's ownership field called the same command and failed too.
# One gate, three doors, every hand-over logged with how the claim was made:
#   --from-watchtower  checked against the record Watchtower wrote (task, owner, < 120 s), consumed once
#   --i-am-human       operator CLI; in an agent environment it needs an interactive confirmation
#   --skip-human-ownership  the old bypass, logged the same way
# Each refusal is paired with a control that differs by one input.

load ../test_helper

UPDATE_TASK="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    unset CLAUDECODE FW_ALLOW_AC_STRUCTURE_DRIFT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    echo "# template" > "$PROJECT_ROOT/.tasks/templates/default.md"
    HLOG="$PROJECT_ROOT/.context/working/owner-handover.jsonl"
    _task T-9950
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_task() {
    cat > "$PROJECT_ROOT/.tasks/active/$1-handover-fixture.md" <<EOF
---
id: $1
name: "Hand-over fixture"
description: "T-4969 fixture"
status: started-work
workflow_type: build
owner: human
horizon: now
tags: []
created: 2026-11-01T00:00:00Z
last_update: 2026-11-01T00:00:00Z
date_finished: null
---

# $1: Hand-over fixture

## Acceptance Criteria

### Agent
- [ ] The one criterion
EOF
}

_owner() { grep -m1 '^owner:' "$PROJECT_ROOT"/.tasks/active/T-9950-*.md | sed 's/owner:[[:space:]]*//'; }

_record() {   # $1 task, $2 owner, $3 age in seconds
    mkdir -p "$PROJECT_ROOT/.context/working/owner-handover"
    python3 -c "import json,sys,time; print(json.dumps({'task':sys.argv[1],'owner':sys.argv[2],'ts':time.time()-float(sys.argv[3]),'by':'watchtower'}))" \
        "$1" "$2" "${3:-0}" > "$PROJECT_ROOT/.context/working/owner-handover/$1.json"
}

_raw_record() {   # $1 raw JSON text for T-9950's record
    mkdir -p "$PROJECT_ROOT/.context/working/owner-handover"
    printf '%s' "$1" > "$PROJECT_ROOT/.context/working/owner-handover/T-9950.json"
}

@test "no door: a bare owner change from human is refused and names both operator paths" {
    run "$UPDATE_TASK" T-9950 --owner agent
    [ "$status" -ne 0 ]
    [[ "$output" == *"Ownership field"* && "$output" == *"--i-am-human"* ]]
    [ "$(_owner)" = "human" ]
    [ ! -e "$HLOG" ]
}

@test "watchtower: a matching fresh record hands over, is consumed, and is logged as a claim" {
    _record T-9950 agent 0
    run "$UPDATE_TASK" T-9950 --owner agent --from-watchtower
    [ "$status" -eq 0 ]
    [ "$(_owner)" = "agent" ]
    [ ! -e "$PROJECT_ROOT/.context/working/owner-handover/T-9950.json" ]
    grep -q '"via": "watchtower (record present, claimed)"' "$HLOG"
}

@test "watchtower: the flag alone, a stale record, or a record for another owner or task is refused" {
    run "$UPDATE_TASK" T-9950 --owner agent --from-watchtower
    [ "$status" -ne 0 ]
    _record T-9950 agent 300
    run "$UPDATE_TASK" T-9950 --owner agent --from-watchtower
    [ "$status" -ne 0 ]
    _record T-9950 human 0
    run "$UPDATE_TASK" T-9950 --owner agent --from-watchtower
    [ "$status" -ne 0 ]
    _record T-9999 agent 0
    run "$UPDATE_TASK" T-9950 --owner agent --from-watchtower
    [ "$status" -ne 0 ]
    [ "$(_owner)" = "human" ]
    [ ! -e "$HLOG" ]
}

@test "operator CLI (no agent env): --i-am-human hands over, logged as a claim" {
    run "$UPDATE_TASK" T-9950 --owner agent --i-am-human
    [ "$status" -eq 0 ]
    [ "$(_owner)" = "agent" ]
    grep -q '"via": "operator CLI (--i-am-human, claimed)"' "$HLOG"
    grep -q '"agent_env": false' "$HLOG"
}

@test "agent env: --i-am-human without an interactive confirmation is refused (with or without the bypass)" {
    CLAUDECODE=1 run "$UPDATE_TASK" T-9950 --owner agent --i-am-human < /dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"interactive confirmation"* ]]
    CLAUDECODE=1 run "$UPDATE_TASK" T-9950 --owner agent --i-am-human --skip-human-ownership --reason x < /dev/null
    [ "$status" -ne 0 ]
    [ "$(_owner)" = "human" ]
    [ ! -e "$HLOG" ]
}

@test "the old bypass still works for the operator and is logged the same way" {
    run "$UPDATE_TASK" T-9950 --owner agent --skip-human-ownership --reason "operator hand-over"
    [ "$status" -eq 0 ]
    [ "$(_owner)" = "agent" ]
    grep -q '"via": "--skip-human-ownership (bypass, claimed)"' "$HLOG"
}

@test "agent -> human stays free and writes no hand-over line" {
    run "$UPDATE_TASK" T-9950 --owner agent --i-am-human
    [ "$status" -eq 0 ]
    : > "$HLOG"
    CLAUDECODE=1 run "$UPDATE_TASK" T-9950 --owner human
    [ "$status" -eq 0 ]
    [ "$(_owner)" = "human" ]
    [ ! -s "$HLOG" ]
}

@test "fw note promote prints a hand-over that works" {
    run grep -c 'fw task update T-XXX --owner agent --i-am-human' "$FRAMEWORK_ROOT/agents/observe/observe.sh"
    [ "$output" -ge 1 ]
    run grep -c 'fw task update T-XXX --owner agent"$' "$FRAMEWORK_ROOT/agents/observe/observe.sh"
    [ "$output" -eq 0 ]
}


# ── T-4969 code review (codex, opencode): attack cases ──────────────────────

@test "review: an agent-written record passes but is logged as a claim, never as verified" {
    # The documented limit: the same OS user can write the record. The log must not overclaim.
    _record T-9950 agent 0
    CLAUDECODE=1 run "$UPDATE_TASK" T-9950 --owner agent --from-watchtower
    [ "$status" -eq 0 ]
    grep -q 'claimed' "$HLOG"
    ! grep -q 'verified' "$HLOG" || false
}

@test "review: a symlinked record is refused and the link target survives" {
    mkdir -p "$PROJECT_ROOT/.context/working/owner-handover"
    python3 -c "import json,time; print(json.dumps({'task':'T-9950','owner':'agent','ts':time.time(),'by':'watchtower'}))" > "$PROJECT_ROOT/forged.json"
    ln -s "$PROJECT_ROOT/forged.json" "$PROJECT_ROOT/.context/working/owner-handover/T-9950.json"
    run "$UPDATE_TASK" T-9950 --owner agent --from-watchtower
    [ "$status" -ne 0 ]
    [ "$(_owner)" = "human" ]
    [ -f "$PROJECT_ROOT/forged.json" ]
}

@test "review: malformed records are refused (JSON shape, ts edge cases, missing by)" {
    local now; now=$(python3 -c 'import time; print(time.time())')
    for body in '[]' 'null' '{not json' \
                "{\"task\":\"T-9950\",\"owner\":\"agent\",\"ts\":\"NaN\",\"by\":\"watchtower\"}" \
                "{\"task\":\"T-9950\",\"owner\":\"agent\",\"ts\":\"Infinity\",\"by\":\"watchtower\"}" \
                "{\"task\":\"T-9950\",\"owner\":\"agent\",\"ts\":$(python3 -c 'import time; print(time.time()+60)'),\"by\":\"watchtower\"}" \
                "{\"task\":\"T-9950\",\"owner\":\"agent\",\"ts\":$now}" \
                "{\"task\":\"T-9950\",\"owner\":\"Agent\",\"ts\":$now,\"by\":\"watchtower\"}"; do
        _raw_record "$body"
        run "$UPDATE_TASK" T-9950 --owner agent --from-watchtower
        [ "$status" -ne 0 ] || { echo "accepted: $body"; return 1; }
    done
    [ "$(_owner)" = "human" ]
    [ ! -e "$HLOG" ]
}

@test "review: piped confirmation in an agent environment is refused" {
    run bash -c "yes T-9950 | CLAUDECODE=1 '$UPDATE_TASK' T-9950 --owner agent --i-am-human"
    [ "$status" -ne 0 ]
    [ "$(_owner)" = "human" ]
}

@test "review: a pty-driven confirmation (script) passes but is logged as a claim" {
    command -v script >/dev/null || skip "util-linux script not installed"
    run bash -c "printf 'T-9950\n' | CLAUDECODE=1 PROJECT_ROOT='$PROJECT_ROOT' script -qec \"'$UPDATE_TASK' T-9950 --owner agent --i-am-human\" /dev/null"
    if [ "$(_owner)" = "agent" ]; then
        grep -q 'tty confirmation in an agent environment, claimed' "$HLOG"
        ! grep -q 'verified' "$HLOG" || false
    fi
}

@test "review: two concurrent consumers of one record — the record is consumed once" {
    _record T-9950 agent 0
    ( "$UPDATE_TASK" T-9950 --owner agent --from-watchtower >/dev/null 2>&1 & \
      "$UPDATE_TASK" T-9950 --owner agent --from-watchtower >/dev/null 2>&1 & wait )
    [ "$(_owner)" = "agent" ]
    [ ! -e "$PROJECT_ROOT/.context/working/owner-handover/T-9950.json" ]
    run grep -c 'record present' "$HLOG"
    [ "$output" -eq 1 ]
}

@test "review: a hand-over whose log line cannot be written is refused and the owner is unchanged" {
    mkdir -p "$HLOG"            # a directory where the log file should be: the append fails
    run "$UPDATE_TASK" T-9950 --owner agent --i-am-human
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not be logged"* ]]
    [ "$(_owner)" = "human" ]
}

@test "review: the gate refuses a task id that is not plain T-NNNN before using it in a path" {
    run grep -c 'if ! \[\[ "\$TASK_ID" =~ \^T-\[0-9\]+\$ \]\]; then' "$UPDATE_TASK"
    [ "$output" -ge 1 ]
}
