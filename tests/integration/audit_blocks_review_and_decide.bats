#!/usr/bin/env bats
# Integration tests for the placeholder audit chokepoint (T-1111/T-1113).
#
# Verifies that `fw task review` and `fw inception decide` both refuse
# to proceed when a task file contains literal template placeholders.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    export NO_COLOR=1
    unset _FW_PATHS_LOADED
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/working"
    # Pretend we're inside a project so fw resolves PROJECT_ROOT correctly
    touch "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_write_placeholder_task() {
    local tid="$1"
    cat > "$PROJECT_ROOT/.tasks/active/${tid}-test.md" <<EOF
---
id: ${tid}
name: "Test inception"
description: Test
status: captured
workflow_type: inception
owner: human
horizon: now
created: 2026-04-11T22:00:00Z
last_update: 2026-04-11T22:00:00Z
---

# ${tid}: Test inception

## Problem Statement
The thing needs investigation.

## Go/No-Go Criteria

### GO if:
- [Criterion 1]
- [Criterion 2]

### NO-GO if:
- [Criterion 1]

## Recommendation
Placeholder — not filled.
EOF
}

_write_clean_task() {
    local tid="$1"
    cat > "$PROJECT_ROOT/.tasks/active/${tid}-test.md" <<EOF
---
id: ${tid}
name: "Clean inception"
description: Test
status: captured
workflow_type: inception
owner: human
horizon: now
created: 2026-04-11T22:00:00Z
last_update: 2026-04-11T22:00:00Z
---

# ${tid}: Clean inception

## Problem Statement
The thing needs investigation.

## Go/No-Go Criteria

### GO if:
- Fix reduces incident rate by 50%
- Regression tests added

### NO-GO if:
- Fix requires rewriting core module

## Recommendation

**Recommendation:** GO — evidence supports the fix.
EOF
}

@test "fw task review: blocks when placeholder present" {
    _write_placeholder_task "T-9001"
    run bash -c "cd '$PROJECT_ROOT' && '$FW' task review T-9001 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Placeholder content detected" ]]
    # No marker file should exist
    [ ! -f "$PROJECT_ROOT/.context/working/.reviewed-T-9001" ]
}

@test "fw task review: proceeds when task is clean" {
    _write_clean_task "T-9002"
    run bash -c "cd '$PROJECT_ROOT' && '$FW' task review T-9002 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "T-9002" ]]
    [ -f "$PROJECT_ROOT/.context/working/.reviewed-T-9002" ]
}

@test "fw inception decide: blocks when placeholder present (even with marker)" {
    _write_placeholder_task "T-9003"
    # Create marker manually — simulating a reviewed task that was later edited
    touch "$PROJECT_ROOT/.context/working/.reviewed-T-9003"
    run bash -c "cd '$PROJECT_ROOT' && '$FW' inception decide T-9003 go --rationale 'test' 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Placeholder content detected" ]]
}

@test "audit error cites the offending line numbers" {
    _write_placeholder_task "T-9004"
    run bash -c "cd '$PROJECT_ROOT' && '$FW' task review T-9004 2>&1"
    [ "$status" -ne 0 ]
    # The placeholder lives around line 23-27 of the fixture
    [[ "$output" =~ "Line " ]]
    [[ "$output" =~ "Criterion 1" ]]
}
