#!/usr/bin/env bats
# Integration tests for fw healing subcommand
#
# Tests the CLI interface for the healing loop:
#   fw healing diagnose T-XXX — analyze task issues
#   fw healing patterns       — show known failure patterns
#   fw healing suggest        — suggestions for tasks with issues

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Help ---

@test "fw healing: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' healing"
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"diagnose"* ]]
}

# --- Patterns ---

@test "fw healing patterns: runs without error" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' healing patterns"
    [ "$status" -eq 0 ]
}

# --- Diagnose ---

@test "fw healing diagnose: fails for nonexistent task" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' healing diagnose T-999"
    [ "$status" -ne 0 ]
}

@test "fw healing diagnose: diagnoses task with issues status" {
    # Create a task with issues status
    cat > "$PROJECT_ROOT/.tasks/active/T-900-test-healing.md" <<'EOF'
---
id: T-900
name: "Test healing target"
description: "Task with issues for testing healing"
status: issues
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: null
---

# T-900: Test healing target

## Context

Test context.

## Acceptance Criteria

- [ ] Test criterion
EOF
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' healing diagnose T-900"
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-900"* ]]
}

# --- Suggest ---

@test "fw healing suggest: runs and shows header" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' healing suggest"
    [[ "$output" == *"HEALING"* ]] || [[ "$output" == *"suggest"* ]]
}

@test "fw healing suggest: detects task with issues" {
    cat > "$PROJECT_ROOT/.tasks/active/T-901-test-suggest.md" <<'EOF'
---
id: T-901
name: "Test suggest target"
description: "Task with issues"
status: issues
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
date_finished: null
---

# T-901: Test suggest target

## Context

Test context.

## Acceptance Criteria

- [ ] Test criterion
EOF
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' healing suggest"
    [[ "$output" == *"T-901"* ]]
}
