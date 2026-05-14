#!/usr/bin/env bats
# T-1836 (T-1831 C-3): P-010 + inception-decide preflight surface a
# body-vs-checkbox drift hint when ACs are unchecked.
#
# Origin: S-2026-0514 errors 1-3 — agent wrote AC content (RCA, candidates,
# recommendation) in task body but didn't tick boxes. The gate error said
# "AC unchecked" with no signal that the fix is "tick the box" rather than
# "redo the work". Sibling to T-1835 (CLAUDE.md documentation half).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export AGENTS_DIR="$FRAMEWORK_ROOT/agents"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export TASKS_DIR="$TEST_TEMP_DIR/.tasks"
    export CONTEXT_DIR="$TEST_TEMP_DIR/.context"
    export NO_COLOR=1

    mkdir -p "$TEST_TEMP_DIR/.tasks/active" \
             "$TEST_TEMP_DIR/.tasks/completed" \
             "$TEST_TEMP_DIR/.context/working" \
             "$TEST_TEMP_DIR/.context/episodic" \
             "$TEST_TEMP_DIR/.context/project"
    echo "id: TEST" > "$TEST_TEMP_DIR/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_task_with_unchecked_and_recommendation() {
    local task_id="$1"
    local f="$TEST_TEMP_DIR/.tasks/active/$task_id-test.md"
    cat > "$f" <<EOF
---
id: $task_id
name: "Body-vs-checkbox drift test"
status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-05-14T00:00:00Z
last_update: 2026-05-14T00:00:00Z
---

# $task_id: Body-vs-checkbox drift

## Acceptance Criteria

### Agent
- [ ] Real work done in body
- [ ] More real work in body

## Recommendation

**Recommendation:** GO
**Rationale:** body content is present
**Evidence:** see body

## Updates
EOF
    echo "$f"
}

_task_with_unchecked_no_recommendation() {
    local task_id="$1"
    local f="$TEST_TEMP_DIR/.tasks/active/$task_id-test.md"
    cat > "$f" <<EOF
---
id: $task_id
name: "No-recommendation drift test"
status: started-work
workflow_type: build
owner: agent
horizon: now
created: 2026-05-14T00:00:00Z
last_update: 2026-05-14T00:00:00Z
---

# $task_id: No recommendation

## Acceptance Criteria

### Agent
- [ ] AC text only, no body work
- [ ] Another empty AC

## Updates
EOF
    echo "$f"
}

@test "P-010: unchecked ACs + filled Recommendation → 'AC content likely present' hint" {
    local task_id="T-9701"
    _task_with_unchecked_and_recommendation "$task_id" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" "$task_id" --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"AC content likely present"* ]]
    [[ "$output" == *"Progressive AC ticking"* ]] || [[ "$output" == *"T-1831 C-4"* ]]
}

@test "P-010: unchecked ACs + no Recommendation → generic Progressive-AC-ticking hint" {
    local task_id="T-9702"
    _task_with_unchecked_no_recommendation "$task_id" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" "$task_id" --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"Progressive AC ticking"* ]] || [[ "$output" == *"T-1831 C-4"* ]]
    # The 'AC content likely present' hint must NOT fire when Recommendation absent.
    [[ "$output" != *"AC content likely present"* ]]
}
