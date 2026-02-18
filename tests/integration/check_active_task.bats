#!/usr/bin/env bats
# Integration tests for agents/context/check-active-task.sh
#
# This script is a PreToolUse hook that gates Write/Edit tool calls
# behind the "nothing gets done without a task" rule.
#
# Exit codes:
#   0 — Allow tool execution
#   2 — Block tool execution
#
# The hook reads JSON from stdin with tool_input.file_path, then checks
# .context/working/focus.yaml for a current_task value.

load ../test_helper

HOOK="$FRAMEWORK_ROOT/agents/context/check-active-task.sh"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.tasks/active"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Helper: invoke the hook with a given file_path in the JSON payload.
# Uses bash -c so the pipe feeds stdin to the script, and bats' run
# captures exit code + output correctly.
run_hook() {
    local file_path="${1:-/some/project/file.py}"
    local json="{\"tool_name\": \"Write\", \"tool_input\": {\"file_path\": \"$file_path\"}}"
    run bash -c "echo '$json' | PROJECT_ROOT='$PROJECT_ROOT' '$HOOK'"
}

# Helper: write a focus.yaml with a given current_task value
write_focus() {
    local task_value="$1"
    cat > "$PROJECT_ROOT/.context/working/focus.yaml" <<EOF
current_task: $task_value
priorities: []
blockers: []
EOF
}

# --- Exempt paths ---

@test "exempt path: .context/ files are always allowed" {
    # No focus.yaml needed — exempt paths bypass all checks
    rm -f "$PROJECT_ROOT/.context/working/focus.yaml"
    run_hook "$PROJECT_ROOT/.context/working/session.yaml"
    [ "$status" -eq 0 ]
}

@test "exempt path: .tasks/ files are always allowed" {
    rm -f "$PROJECT_ROOT/.context/working/focus.yaml"
    run_hook "$PROJECT_ROOT/.tasks/active/T-001-new-task.md"
    [ "$status" -eq 0 ]
}

@test "exempt path: .claude/ files are always allowed" {
    rm -f "$PROJECT_ROOT/.context/working/focus.yaml"
    run_hook "$PROJECT_ROOT/.claude/settings.json"
    [ "$status" -eq 0 ]
}

@test "exempt path: .git/ files are always allowed" {
    rm -f "$PROJECT_ROOT/.context/working/focus.yaml"
    run_hook "$PROJECT_ROOT/.git/config"
    [ "$status" -eq 0 ]
}

# --- Bootstrap case ---

@test "bootstrap: no .context/working directory allows execution" {
    rm -rf "$PROJECT_ROOT/.context/working"
    run_hook "/some/project/file.py"
    [ "$status" -eq 0 ]
}

# --- No focus.yaml ---

@test "no focus.yaml: allows with warning about context init" {
    rm -f "$PROJECT_ROOT/.context/working/focus.yaml"
    run_hook "/some/project/file.py"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Context not initialized"* ]]
}

# --- focus.yaml with current_task: null ---

@test "current_task null: blocks execution with exit 2" {
    write_focus "null"
    run_hook "/some/project/file.py"
    [ "$status" -eq 2 ]
}

@test "current_task null: blocked message contains BLOCKED" {
    write_focus "null"
    run_hook "/some/project/file.py"
    [ "$status" -eq 2 ]
    [[ "$output" == *"BLOCKED"* ]]
}

@test "current_task null: blocked message shows file path" {
    write_focus "null"
    run_hook "/some/project/file.py"
    [ "$status" -eq 2 ]
    [[ "$output" == *"/some/project/file.py"* ]]
}

@test "current_task null: blocked message shows unblock instructions" {
    write_focus "null"
    run_hook "/some/project/file.py"
    [ "$status" -eq 2 ]
    [[ "$output" == *"fw task create"* ]]
    [[ "$output" == *"fw context focus"* ]]
}

# --- focus.yaml with empty current_task ---

@test "current_task empty: blocks execution with exit 2" {
    # Write focus with empty value (YAML empty string)
    printf 'current_task: \npriorities: []\nblockers: []\n' \
        > "$PROJECT_ROOT/.context/working/focus.yaml"
    run_hook "/some/project/file.py"
    [ "$status" -eq 2 ]
    [[ "$output" == *"BLOCKED"* ]]
}

# --- focus.yaml with valid task ---

@test "valid task: allows execution with exit 0" {
    write_focus "T-042"
    run_hook "/some/project/file.py"
    [ "$status" -eq 0 ]
}

@test "valid task: no BLOCKED message in output" {
    write_focus "T-042"
    run_hook "/some/project/file.py"
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED"* ]]
}

# --- Inception task awareness ---

@test "inception task without decision: allows with NOTE on stderr" {
    write_focus "T-050"
    # Create an inception task file without a decision line
    cat > "$PROJECT_ROOT/.tasks/active/T-050-explore-auth.md" <<'TASK'
---
id: T-050
name: Explore auth options
description: Inception exploration
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: null
---

# T-050: Explore auth options

## Context

Exploring authentication approaches.

## Acceptance Criteria

- [ ] Decision recorded
TASK
    run_hook "/some/project/file.py"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOTE"* ]]
    [[ "$output" == *"inception"* ]]
}

@test "inception task with GO decision: allows without NOTE" {
    write_focus "T-051"
    # Create an inception task file WITH a GO decision
    cat > "$PROJECT_ROOT/.tasks/active/T-051-explore-db.md" <<'TASK'
---
id: T-051
name: Explore DB options
description: Inception exploration
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: null
---

# T-051: Explore DB options

## Context

Exploring database approaches.

**Decision**: GO — proceed with PostgreSQL
TASK
    run_hook "/some/project/file.py"
    [ "$status" -eq 0 ]
    [[ "$output" != *"NOTE"* ]]
}

@test "build task: allows without any inception NOTE" {
    write_focus "T-042"
    # Create a build-type task (not inception)
    cat > "$PROJECT_ROOT/.tasks/active/T-042-fix-login.md" <<'TASK'
---
id: T-042
name: Fix login bug
description: Fix the login bug
status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: null
---

# T-042: Fix login bug

## Context

Bug in login flow.
TASK
    run_hook "/some/project/file.py"
    [ "$status" -eq 0 ]
    [[ "$output" != *"NOTE"* ]]
    [[ "$output" != *"inception"* ]]
}

# --- Edge cases ---

@test "malformed JSON input: with valid focus allows gracefully" {
    write_focus "T-042"
    run bash -c "echo 'not valid json' | PROJECT_ROOT='$PROJECT_ROOT' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "exempt paths bypass even when focus would block" {
    # Even with null task (which would block), exempt paths are allowed
    write_focus "null"
    run_hook "$PROJECT_ROOT/.tasks/active/T-001-new.md"
    [ "$status" -eq 0 ]
}

@test "blocked message references P-002 policy" {
    write_focus "null"
    run_hook "/some/project/file.py"
    [ "$status" -eq 2 ]
    [[ "$output" == *"P-002"* ]]
}
