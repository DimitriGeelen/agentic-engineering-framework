#!/usr/bin/env bats
# Unit tests for agents/healing/lib/suggest.sh
#
# Tests: do_suggest (scan for tasks with issues/blocked status)

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    mkdir -p "$TASKS_DIR/active" "$PROJECT_ROOT/.context"
    # Disable colors for predictable output matching
    RED='' GREEN='' YELLOW='' CYAN='' BLUE='' NC=''
    source "$FRAMEWORK_ROOT/agents/healing/lib/suggest.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: create a task file with a given status
create_task_with_status() {
    local task_id="$1"
    local slug="$2"
    local status="$3"
    local name="${4:-Test task $task_id}"
    cat > "$TASKS_DIR/active/${task_id}-${slug}.md" <<EOF
---
id: ${task_id}
name: ${name}
description: "A test task"
status: ${status}
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: null
---

# ${task_id}: ${name}

## Context

Test context.

## Acceptance Criteria

- [ ] Test criterion

## Updates

### 2026-01-15 Update
Hit a blocker with the API.
EOF
}

# --- No tasks with issues ---

@test "do_suggest: no tasks at all shows no issues message" {
    run do_suggest
    [ "$status" -eq 0 ]
    [[ "$output" == *"No tasks with issues or blocked status"* ]]
}

@test "do_suggest: only started-work tasks shows no issues" {
    create_task_with_status "T-010" "working-fine" "started-work"
    run do_suggest
    [ "$status" -eq 0 ]
    [[ "$output" == *"No tasks with issues or blocked status"* ]]
}

# --- Tasks with issues ---

@test "do_suggest: one task with issues status is listed" {
    create_task_with_status "T-015" "api-timeout" "issues" "API timeout fix"
    run do_suggest
    [ "$status" -eq 0 ]
    [[ "$output" == *"HEALING SUGGESTIONS"* ]]
    [[ "$output" == *"T-015"* ]]
    [[ "$output" == *"API timeout fix"* ]]
    [[ "$output" == *"Status: issues"* ]]
}

# --- Tasks with blocked status ---

@test "do_suggest: one task with blocked status is listed" {
    create_task_with_status "T-020" "blocked-dep" "blocked" "Blocked on dependency"
    run do_suggest
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-020"* ]]
    [[ "$output" == *"Blocked on dependency"* ]]
    [[ "$output" == *"Status: blocked"* ]]
}

# --- Multiple problem tasks ---

@test "do_suggest: multiple tasks with issues and blocked shows all" {
    create_task_with_status "T-015" "api-timeout" "issues" "API timeout fix"
    create_task_with_status "T-020" "blocked-dep" "blocked" "Blocked on dependency"
    create_task_with_status "T-025" "another-issue" "issues" "Another issue"
    run do_suggest
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-015"* ]]
    [[ "$output" == *"T-020"* ]]
    [[ "$output" == *"T-025"* ]]
}

# --- Count ---

@test "do_suggest: total count matches number of problem tasks" {
    create_task_with_status "T-015" "api-timeout" "issues" "API timeout fix"
    create_task_with_status "T-020" "blocked-dep" "blocked" "Blocked on dependency"
    # Also add a non-problem task to ensure it is not counted
    create_task_with_status "T-030" "fine-task" "started-work" "Fine task"
    run do_suggest
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total tasks needing attention: 2"* ]]
}

@test "do_suggest: single problem task shows count of 1" {
    create_task_with_status "T-015" "api-timeout" "issues" "API timeout fix"
    run do_suggest
    [ "$status" -eq 0 ]
    [[ "$output" == *"Total tasks needing attention: 1"* ]]
}

# --- Diagnose action hint ---

@test "do_suggest: output includes diagnose action hint" {
    create_task_with_status "T-015" "api-timeout" "issues" "API timeout fix"
    run do_suggest
    [ "$status" -eq 0 ]
    [[ "$output" == *"healing.sh diagnose T-015"* ]]
}

# --- Mixed statuses ---

@test "do_suggest: non-problem statuses are excluded from results" {
    create_task_with_status "T-010" "working" "started-work" "Working task"
    create_task_with_status "T-011" "completed" "work-completed" "Done task"
    create_task_with_status "T-015" "has-issues" "issues" "Problem task"
    run do_suggest
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-015"* ]]
    [[ "$output" != *"T-010"* ]]
    [[ "$output" != *"T-011"* ]]
    [[ "$output" == *"Total tasks needing attention: 1"* ]]
}
