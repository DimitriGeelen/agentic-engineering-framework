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

@test "no door: a bare owner change from human is refused and names both operator paths" {
    run "$UPDATE_TASK" T-9950 --owner agent
    [ "$status" -ne 0 ]
    [[ "$output" == *"Ownership field"* && "$output" == *"--i-am-human"* ]]
    [ "$(_owner)" = "human" ]
    [ ! -e "$HLOG" ]
}

@test "watchtower: a matching fresh record hands over, is consumed, and is logged as verified" {
    _record T-9950 agent 0
    run "$UPDATE_TASK" T-9950 --owner agent --from-watchtower
    [ "$status" -eq 0 ]
    [ "$(_owner)" = "agent" ]
    [ ! -e "$PROJECT_ROOT/.context/working/owner-handover/T-9950.json" ]
    grep -q '"via": "watchtower (record verified)"' "$HLOG"
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
