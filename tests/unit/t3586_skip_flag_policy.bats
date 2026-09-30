#!/usr/bin/env bats
# T-3586 — the completion gate's --skip-* flags.
#
# Origin: T-3583's dispatched worker closed its task with --skip-acceptance-criteria
# and an EMPTY reason, leaving two criteria unbuilt against its prompt. The flag was
# accepted with no reason and no agent check. Policy now (update-task.sh
# enforce_bypass_policy): every CONSUMED --skip-* needs a reason; the flags whose gate
# protects a criterion or ownership are refused under CLAUDECODE=1 unless --i-am-human.
#
# Each refusal test is paired with a control that differs by exactly one input, so a
# gate that refuses everything (or nothing) fails at least one of them.

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
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" \
       "$PROJECT_ROOT/.tasks/templates/default.md" 2>/dev/null || \
       echo "# template" > "$PROJECT_ROOT/.tasks/templates/default.md"
    LOG="$PROJECT_ROOT/.context/working/.gate-bypass-log.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# $1 id, $2 agent AC box ("x" or " "), $3 verification line (optional), $4 owner
_task() {
    local id="$1" box="$2" verif="${3:-}" owner="${4:-agent}"
    cat > "$PROJECT_ROOT/.tasks/active/${id}-policy-fixture.md" <<EOF
---
id: $id
name: "Policy fixture"
description: "T-3586 fixture"
status: started-work
workflow_type: build
owner: $owner
horizon: now
tags: []
created: 2026-09-30T00:00:00Z
last_update: 2026-09-30T00:00:00Z
date_finished: null
---

# $id: Policy fixture

## Acceptance Criteria

### Agent
- [$box] The one criterion

## Verification
$verif

## Recommendation

**Recommendation:** GO

**Rationale:** fixture.
EOF
}

_closed() { [ -n "$(find "$PROJECT_ROOT/.tasks/completed" -name "$1-*.md")" ]; }

# ── --skip-acceptance-criteria: the T-3583 hole ────────────────────────────────

@test "agent: --skip-acceptance-criteria WITH a reason is refused and the task stays open" {
    _task T-9901 " "
    CLAUDECODE=1 run "$UPDATE_TASK" T-9901 --status work-completed --skip-acceptance-criteria --reason "deferred"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refused in an agent session"* ]]
    ! _closed T-9901
    [ ! -s "$LOG" ]
}

@test "agent: refusal names the right paths (finish, split into a task, stop and report)" {
    _task T-9902 " "
    CLAUDECODE=1 run "$UPDATE_TASK" T-9902 --status work-completed --skip-acceptance-criteria --reason "x"
    [[ "$output" == *"Finish the work"* ]]
    [[ "$output" == *"bin/fw task create"* ]]
    [[ "$output" == *"stop and report"* ]]
}

@test "agent: the T-3583 shape exactly (no reason at all) is refused" {
    _task T-9903 " "
    CLAUDECODE=1 run "$UPDATE_TASK" T-9903 --status work-completed --skip-acceptance-criteria
    [ "$status" -ne 0 ]
    ! _closed T-9903
}

@test "human (no CLAUDECODE) with a reason: allowed, and the reason is logged" {
    _task T-9904 " "
    run "$UPDATE_TASK" T-9904 --status work-completed --skip-acceptance-criteria --reason "operator ruling 42"
    [ "$status" -eq 0 ]
    _closed T-9904
    grep -q "flag: '--skip-acceptance-criteria'" "$LOG"
    grep -q "reason: 'operator ruling 42'" "$LOG"
}

@test "human with an EMPTY reason is refused" {
    _task T-9905 " "
    run "$UPDATE_TASK" T-9905 --status work-completed --skip-acceptance-criteria
    [ "$status" -ne 0 ]
    [[ "$output" == *"needs a reason"* ]]
    ! _closed T-9905
}

@test "human with a whitespace-only reason is refused" {
    _task T-9906 " "
    run "$UPDATE_TASK" T-9906 --status work-completed --skip-acceptance-criteria --reason "   "
    [ "$status" -ne 0 ]
    [[ "$output" == *"needs a reason"* ]]
}

@test "agent with --i-am-human and a reason: allowed, logged as an override under CLAUDECODE" {
    _task T-9907 " "
    CLAUDECODE=1 run "$UPDATE_TASK" T-9907 --status work-completed --skip-acceptance-criteria --i-am-human --reason "operator at the keyboard"
    [ "$status" -eq 0 ]
    _closed T-9907
    grep -q "i-am-human under CLAUDECODE=1" "$LOG"
}

@test "agent with --i-am-human but no reason: still refused (the reason rule has no override)" {
    _task T-9908 " "
    CLAUDECODE=1 run "$UPDATE_TASK" T-9908 --status work-completed --skip-acceptance-criteria --i-am-human
    [ "$status" -ne 0 ]
    [[ "$output" == *"needs a reason"* ]]
}

@test "control: agent with every criterion ticked closes normally (the flag is only judged when consumed)" {
    _task T-9909 "x"
    CLAUDECODE=1 run "$UPDATE_TASK" T-9909 --status work-completed --skip-acceptance-criteria
    [ "$status" -eq 0 ]
    _closed T-9909
    [ ! -s "$LOG" ]
}

# ── sibling flags ──────────────────────────────────────────────────────────────

@test "agent: --skip-verification over a failing verification line is refused" {
    _task T-9910 "x" "false"
    CLAUDECODE=1 run "$UPDATE_TASK" T-9910 --status work-completed --skip-verification --reason "flaky"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--skip-verification is refused"* ]]
    ! _closed T-9910
}

@test "human: --skip-verification with a reason passes the same failing line" {
    _task T-9911 "x" "false"
    run "$UPDATE_TASK" T-9911 --status work-completed --skip-verification --reason "host lacks tool"
    [ "$status" -eq 0 ]
    _closed T-9911
}

@test "agent: --skip-sovereignty on a human-owned task is refused" {
    _task T-9912 "x" "" human
    CLAUDECODE=1 run "$UPDATE_TASK" T-9912 --status work-completed --skip-sovereignty --reason "x"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--skip-sovereignty is refused"* ]]
    ! _closed T-9912
}

@test "agent: --skip-human-ownership (owner human -> agent) is refused and the owner is unchanged" {
    _task T-9913 " " "" human
    CLAUDECODE=1 run "$UPDATE_TASK" T-9913 --owner agent --skip-human-ownership --reason "x"
    [ "$status" -ne 0 ]
    grep -q "^owner: human" "$PROJECT_ROOT"/.tasks/active/T-9913-*.md
}

@test "agent: --skip-render-review stays agent-usable (T-3557 ruling) but needs a reason" {
    run grep -q ' --skip-render-review ' <(grep '^_BYPASS_REASON_REQUIRED=' "$UPDATE_TASK")
    [ "$status" -eq 0 ]
    run grep -q ' --skip-render-review ' <(grep '^_BYPASS_AGENT_REFUSED=' "$UPDATE_TASK")
    [ "$status" -ne 0 ]
}

@test "policy function: agent-usable flag with reason passes; without reason refuses" {
    run bash -c "
        RED= NC= I_AM_HUMAN=false CLAUDECODE=1
        eval \"\$(sed -n '/^_BYPASS_AGENT_REFUSED=/,/^}/p' '$UPDATE_TASK')\"
        enforce_bypass_policy --skip-evolution 'arc slice is doc-only' && echo PASSED"
    [ "$status" -eq 0 ]
    [[ "$output" == *PASSED* ]]
    run bash -c "
        RED= NC= I_AM_HUMAN=false CLAUDECODE=1
        eval \"\$(sed -n '/^_BYPASS_AGENT_REFUSED=/,/^}/p' '$UPDATE_TASK')\"
        enforce_bypass_policy --skip-evolution '' && echo PASSED"
    [ "$status" -ne 0 ]
    [[ "$output" != *PASSED* ]]
}

@test "policy function: every protected flag is refused for an agent, allowed for a human" {
    for f in --skip-acceptance-criteria --skip-verification --skip-sovereignty \
             --skip-human-ownership --skip-rca --skip-recommendation --skip-inception-decision; do
        run bash -c "
            RED= NC= I_AM_HUMAN=false CLAUDECODE=1
            eval \"\$(sed -n '/^_BYPASS_AGENT_REFUSED=/,/^}/p' '$UPDATE_TASK')\"
            enforce_bypass_policy $f 'a reason'"
        [ "$status" -ne 0 ] || { echo "agent not refused: $f"; false; }
        run bash -c "
            RED= NC= I_AM_HUMAN=false CLAUDECODE=
            eval \"\$(sed -n '/^_BYPASS_AGENT_REFUSED=/,/^}/p' '$UPDATE_TASK')\"
            enforce_bypass_policy $f 'a reason'"
        [ "$status" -eq 0 ] || { echo "human refused: $f"; false; }
    done
}

@test "--force under CLAUDECODE=1 cannot skip a criterion either" {
    _task T-9914 " "
    CLAUDECODE=1 run "$UPDATE_TASK" T-9914 --status work-completed --force --reason "x"
    [ "$status" -ne 0 ]
    ! _closed T-9914
}
