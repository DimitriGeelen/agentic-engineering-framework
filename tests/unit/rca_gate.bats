#!/usr/bin/env bats
# T-1550 — RCA gate for bug-class task completion.
#
# Bug-class detection: workflow_type ∉ {inception, specification, design}
# AND (tags match bug|bugfix|hotfix|rca|incident OR title matches
# fix|bug|rca|broken|crash|error|regression|fail|hotfix).
#
# Behavior: when bug-class AND --status work-completed AND ## RCA section
# is missing or empty, completion is BLOCKED. --skip-rca bypasses with log.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$PROJECT_ROOT/.tasks/active" \
             "$PROJECT_ROOT/.tasks/completed" \
             "$CONTEXT_DIR/working" \
             "$CONTEXT_DIR/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Build a task file with controlled fields. Last arg is the body content
# AFTER the frontmatter (must include the sections you want to test).
_make_task() {
    local task_id="$1"
    local title="$2"
    local workflow_type="$3"
    local tags="$4"
    local body="$5"
    local file="$PROJECT_ROOT/.tasks/active/${task_id}-test.md"
    cat > "$file" <<EOF
---
id: ${task_id}
name: "${title}"
description: test
status: started-work
workflow_type: ${workflow_type}
owner: agent
horizon: now
tags: ${tags}
components: []
related_tasks: []
created: 2026-04-27T00:00:00Z
last_update: 2026-04-27T00:00:00Z
date_finished: null
---

# ${task_id}: ${title}

${body}
EOF
    echo "$file"
}

# Standard body w/ all gates pre-cleared except RCA. ACs ticked.
# Pass any extra sections (## RCA ...) as $1.
_body_minimal() {
    local extra="${1:-}"
    cat <<EOF
## Context
test.

## Acceptance Criteria

### Agent
- [x] Done

## Verification

echo ok

## Recommendation
**Recommendation:** GO
**Rationale:** test
**Evidence:** test

${extra}
EOF
}

@test "bug-class task (title 'Fix') with no ## RCA section → BLOCKED" {
    cd "$PROJECT_ROOT"
    local body
    body="$(_body_minimal)"
    _make_task "T-9001" "Fix the broken thing" "build" "[bug]" "$body" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9001 \
        --status work-completed --skip-acceptance-criteria
    [ "$status" -ne 0 ]
    [[ "$output" == *"## RCA section is missing"* ]]
}

@test "bug-class task with empty ## RCA section (only template comments) → BLOCKED" {
    cd "$PROJECT_ROOT"
    local rca_section='## RCA

<!-- placeholder comment, no real content -->
'
    local body
    body="$(_body_minimal "$rca_section")"
    _make_task "T-9002" "Fix something else" "build" "[bug]" "$body" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9002 \
        --status work-completed --skip-acceptance-criteria
    [ "$status" -ne 0 ]
    [[ "$output" == *"## RCA section is empty"* ]]
}

@test "bug-class task with substantive ## RCA → PASSES" {
    cd "$PROJECT_ROOT"
    local rca_section='## RCA

**Symptom:** the thing did the wrong thing in this specific way that we observed.
**Root cause:** the underlying cause was that this structural assumption did not hold here.
**Why structurally allowed:** no test exercised this path so the regression slipped through.
**Prevention:** add a regression test for this path and a lint rule to catch the antipattern.
'
    local body
    body="$(_body_minimal "$rca_section")"
    _make_task "T-9003" "Fix the regression" "build" "[bug]" "$body" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9003 \
        --status work-completed --skip-acceptance-criteria
    [ "$status" -eq 0 ]
    [[ "$output" == *"RCA: substantive"* ]]
}

@test "inception task without ## RCA → PASSES (excluded from gate)" {
    cd "$PROJECT_ROOT"
    local body
    body="$(_body_minimal)"
    _make_task "T-9004" "Fix-related inception exploration" "inception" "[]" "$body" >/dev/null
    # T-2733: --skip-inception-decision is about a DIFFERENT gate. G-052/T-1626
    # landed after this suite and refuses any inception close without a recorded
    # decision, so the fixture stopped reaching the assertion this test is about
    # (that the RCA gate EXCLUDES inceptions). Scoping the unrelated gate out
    # keeps the RCA assertion meaningful rather than passing on a wrong reason.
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9004 \
        --status work-completed --skip-acceptance-criteria --skip-inception-decision
    [ "$status" -eq 0 ]
    [[ "$output" != *"## RCA section is"* ]]
}

@test "non-bug-class build task without ## RCA → PASSES (not bug-class)" {
    cd "$PROJECT_ROOT"
    local body
    body="$(_body_minimal)"
    _make_task "T-9005" "Add new dashboard widget" "build" "[ui]" "$body" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9005 \
        --status work-completed --skip-acceptance-criteria
    [ "$status" -eq 0 ]
    [[ "$output" != *"## RCA section is"* ]]
}

# --- T-2132: "fix request" / "feature request" false-positive fixes ---

@test "title 'Upstream fix request' build task without RCA → PASSES (not bug-class)" {
    cd "$PROJECT_ROOT"
    local body
    body="$(_body_minimal)"
    _make_task "T-9010" "Upstream fix request: fw hook-enable --script" "build" "[]" "$body" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9010 \
        --status work-completed --skip-acceptance-criteria
    [ "$status" -eq 0 ]
    [[ "$output" != *"## RCA section is"* ]]
}

@test "title 'Feature request' build task without RCA → PASSES (not bug-class)" {
    cd "$PROJECT_ROOT"
    local body
    body="$(_body_minimal)"
    _make_task "T-9011" "Feature request: add baz support" "build" "[]" "$body" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9011 \
        --status work-completed --skip-acceptance-criteria
    [ "$status" -eq 0 ]
    [[ "$output" != *"## RCA section is"* ]]
}

@test "workflow_type 'request' with bug-keyword title → PASSES (type override)" {
    cd "$PROJECT_ROOT"
    local body
    body="$(_body_minimal)"
    _make_task "T-9012" "Fix the broken widget" "request" "[]" "$body" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9012 \
        --status work-completed --skip-acceptance-criteria
    [ "$status" -eq 0 ]
    [[ "$output" != *"## RCA section is"* ]]
}

@test "tags [feature] with bug-keyword title → PASSES (tag override)" {
    cd "$PROJECT_ROOT"
    local body
    body="$(_body_minimal)"
    _make_task "T-9013" "Fix the broken widget" "build" "[feature]" "$body" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9013 \
        --status work-completed --skip-acceptance-criteria
    [ "$status" -eq 0 ]
    [[ "$output" != *"## RCA section is"* ]]
}

@test "regression: genuine bug title 'Fix: crash on empty input' → STILL BLOCKED" {
    cd "$PROJECT_ROOT"
    local body
    body="$(_body_minimal)"
    _make_task "T-9014" "Fix: crash on empty input" "build" "[]" "$body" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9014 \
        --status work-completed --skip-acceptance-criteria
    [ "$status" -ne 0 ]
    [[ "$output" == *"## RCA section is missing"* ]]
}

@test "regression: 'Hotfix for prod CSS regression' → STILL BLOCKED" {
    cd "$PROJECT_ROOT"
    local body
    body="$(_body_minimal)"
    _make_task "T-9015" "Hotfix for prod CSS regression" "build" "[]" "$body" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9015 \
        --status work-completed --skip-acceptance-criteria
    [ "$status" -ne 0 ]
    [[ "$output" == *"## RCA section is missing"* ]]
}

@test "--skip-rca bypasses bug-class block AND logs to gate-bypass-log.yaml" {
    cd "$PROJECT_ROOT"
    local body
    body="$(_body_minimal)"
    _make_task "T-9006" "Fix the bypass case" "build" "[bug]" "$body" >/dev/null
    run "$FRAMEWORK_ROOT/agents/task-create/update-task.sh" T-9006 \
        --status work-completed --skip-acceptance-criteria --skip-rca
    [ "$status" -eq 0 ]
    [[ "$output" == *"--skip-rca bypass"* ]]
    [ -f "$CONTEXT_DIR/working/.gate-bypass-log.yaml" ]
    grep -q "T-9006" "$CONTEXT_DIR/working/.gate-bypass-log.yaml"
    grep -q "skip-rca" "$CONTEXT_DIR/working/.gate-bypass-log.yaml"
}
