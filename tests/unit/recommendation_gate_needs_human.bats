#!/usr/bin/env bats
# T-1572 / F6 — Regression: Recommendation gate must fire on reviewer.needs_human
# signals (frontmatter risk, human_signoff, prior reviewer verdict), not just
# PARTIAL_COMPLETE. Closes the cross-component decoupling identified in T-1565
# audit: lib/reviewer/static_scan.py:668 says "needs human" for risk={high,medium}
# OR human_signoff:required, but the artefact gate didn't enforce.

load ../test_helper

UPDATE_TASK="$FRAMEWORK_ROOT/agents/task-create/update-task.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.tasks/completed" \
             "$PROJECT_ROOT/.tasks/templates" \
             "$PROJECT_ROOT/.context/working" \
             "$PROJECT_ROOT/.context/episodic"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" \
       "$PROJECT_ROOT/.tasks/templates/default.md" 2>/dev/null || \
       echo "# template" > "$PROJECT_ROOT/.tasks/templates/default.md"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Task with no Human ACs (so PARTIAL_COMPLETE=false) and no Recommendation block.
# Caller provides extra frontmatter or appended verdict block to trigger the gate.
_make_no_partial_task() {
    local id="$1"
    local extra_fm="${2:-}"
    local extra_body="${3:-}"
    local task_file="$PROJECT_ROOT/.tasks/active/${id}-test-task.md"
    cat > "$task_file" <<EOF
---
id: $id
name: "Test needs-human signal task"
description: "T-1572 F6 fixture"
status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: []
created: 2026-04-27T00:00:00Z
last_update: 2026-04-27T00:00:00Z
date_finished: null
${extra_fm}---

# $id: Test needs-human signal

## Acceptance Criteria

### Agent
- [x] Agent finished

## Verification

${extra_body}
EOF
    echo "$task_file"
}

@test "baseline: no Human ACs + no needs-human signal + no Recommendation → completes" {
    _make_no_partial_task "T-9981"
    run "$UPDATE_TASK" T-9981 --status work-completed
    [ "$status" -eq 0 ]
    [ ! -f "$PROJECT_ROOT/.tasks/active/T-9981-test-task.md" ]
}

@test "F6 trigger: human_signoff:required without Recommendation → blocks" {
    _make_no_partial_task "T-9982" "human_signoff: required
"
    run "$UPDATE_TASK" T-9982 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"Recommendation"* ]]
    [[ "$output" == *"needs human review"* ]]
    [ -f "$PROJECT_ROOT/.tasks/active/T-9982-test-task.md" ]
}

@test "F6 trigger: risk:high without Recommendation → blocks" {
    _make_no_partial_task "T-9983" "risk: high
"
    run "$UPDATE_TASK" T-9983 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"Recommendation"* ]]
}

@test "F6 trigger: risk:medium without Recommendation → blocks" {
    _make_no_partial_task "T-9984" "risk: medium
"
    run "$UPDATE_TASK" T-9984 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"Recommendation"* ]]
}

@test "F6 trigger: prior reviewer verdict needs_human=yes without Recommendation → blocks" {
    _make_no_partial_task "T-9985" "" "## Reviewer Verdict (v1.4)

- **Overall:** WARN
- **Needs Human:** yes
- **Findings:** 2
"
    run "$UPDATE_TASK" T-9985 --status work-completed
    [ "$status" -ne 0 ]
    [[ "$output" == *"Recommendation"* ]]
}

@test "F6 trigger: --skip-recommendation bypass works on needs-human signal" {
    _make_no_partial_task "T-9986" "risk: high
"
    run "$UPDATE_TASK" T-9986 --status work-completed --skip-recommendation
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [ -f "$PROJECT_ROOT/.tasks/completed/T-9986-test-task.md" ]
}

@test "F6 no false positive: risk:low (not high/medium) → no block" {
    _make_no_partial_task "T-9987" "risk: low
"
    run "$UPDATE_TASK" T-9987 --status work-completed
    [ "$status" -eq 0 ]
    [ ! -f "$PROJECT_ROOT/.tasks/active/T-9987-test-task.md" ]
}

@test "F6 no false positive: reviewer verdict needs_human=no → no block" {
    _make_no_partial_task "T-9988" "" "## Reviewer Verdict (v1.4)

- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
"
    run "$UPDATE_TASK" T-9988 --status work-completed
    [ "$status" -eq 0 ]
}
