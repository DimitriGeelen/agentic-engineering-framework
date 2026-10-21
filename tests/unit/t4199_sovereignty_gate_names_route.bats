#!/usr/bin/env bats
# T-4199 — the R-033 sovereignty gate pointed a human-owned task with ZERO Human
# criteria at /review/<id> and nothing else. That page shows "Human ACs: 0/0" and
# has no close control, so the operator was left at a dead end (dimitri-mint-dev
# P-014, their T-110). Since T-4156 the working route for that class is
# `fw task delegate` → `fw reviewer judge`; the gate must name it.
#
# COUNTERFACTUAL: revert the route block in check_human_sovereignty and leg 1 goes
# red on the "task delegate" assertion. Legs 2 and 3 pin that the route is NOT
# offered where it does not apply (a task with a real Human criterion, a carve-out).

load ../test_helper

UPDATE_TASK="$BATS_TEST_DIRNAME/../../agents/task-create/update-task.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    unset FW_SIDECAR_AGENT_ID FW_REVIEW_WORKER FW_DISPATCHED_WORKER
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/episodic" "$PROJECT_ROOT/bin"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    ln -sf "$FRAMEWORK_ROOT/bin/fw" "$PROJECT_ROOT/bin/fw"
    git -C "$PROJECT_ROOT" init -q
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# $1 = Agent criterion text, $2 = Human section body
_make_task() {
    cat > "$PROJECT_ROOT/.tasks/active/T-9300-fixture.md" <<TASK
---
id: T-9300
name: "fixture"
description: "human-owned fixture"
status: started-work
workflow_type: specification
owner: human
horizon: now
tags: []
components: []
created: 2026-10-01T00:00:00Z
last_update: 2026-10-01T00:00:00Z
date_finished: null
---

# T-9300: fixture

## Acceptance Criteria

### Agent
- [x] $1

### Human
$2

## Verification
true

## Recommendation

**Recommendation:** GO

**Rationale:** Fixture.

## Updates
TASK
}

@test "0 Human criteria: the refusal names the delegate -> reviewer judge route" {
    _make_task "Spec document written" "<!-- template example only
     - [ ] [REVIEW] example
-->"
    run "$UPDATE_TASK" T-9300 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"Cannot complete human-owned task"* ]]
    [[ "$output" == *"no Human criteria"* ]]
    [[ "$output" == *"bin/fw task delegate T-9300"* ]]
    [[ "$output" == *"bin/fw reviewer judge T-9300"* ]]
    # still owned by the human, still in active/
    [ -f "$PROJECT_ROOT/.tasks/active/T-9300-fixture.md" ]
}

@test "a real open Human criterion: no delegate route is offered" {
    _make_task "Spec document written" "- [ ] [REVIEW] The spec reads clearly
  **Steps:** 1. read it
  **Expected:** clear
  **If not:** note it"
    run "$UPDATE_TASK" T-9300 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"Cannot complete human-owned task"* ]]
    [[ "$output" != *"bin/fw reviewer judge T-9300"* ]]
}

@test "carve-out (tier-0/act-in-the-world) with 0 Human criteria stays with the operator" {
    _make_task "Force push the release branch to production" ""
    run "$UPDATE_TASK" T-9300 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" != *"bin/fw reviewer judge T-9300"* ]]
    [[ "$output" == *"stays with the operator"* ]]
}
