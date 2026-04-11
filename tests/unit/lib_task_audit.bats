#!/usr/bin/env bats
# Unit tests for lib/task-audit.sh (T-1111/T-1113)
#
# Verifies the placeholder audit chokepoint catches literal template stubs
# and does not flag legitimate authored content.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/task-audit.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_make_task() {
    local content="$1"
    local file="$TEST_TEMP_DIR/task.md"
    printf '%s\n' "$content" > "$file"
    echo "$file"
}

@test "audit: clean task passes" {
    local f
    f=$(_make_task "---
id: T-001
---

# T-001: Test

## Problem Statement
Fix the thing.

## Go/No-Go Criteria

### GO if:
- Build succeeds
- Tests green

### NO-GO if:
- Build fails
- Tests red

## Recommendation
GO — all evidence supports fix.")
    run audit_task_placeholders "$f"
    [ "$status" -eq 0 ]
}

@test "audit: detects Criterion 1 placeholder" {
    local f
    f=$(_make_task "## Go/No-Go Criteria

### GO if:
- [Criterion 1]
- [Criterion 2]")
    run audit_task_placeholders "$f"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Placeholder content detected" ]]
}

@test "audit: detects bracketed-TODO placeholder" {
    local f
    f=$(_make_task "## Recommendation
[TODO]")
    run audit_task_placeholders "$f"
    [ "$status" -eq 1 ]
}

@test "audit: detects bracketed-PLACEHOLDER token" {
    local f
    f=$(_make_task "## Problem Statement
[PLACEHOLDER] fill in here")
    run audit_task_placeholders "$f"
    [ "$status" -eq 1 ]
}

@test "audit: detects 'Your recommendation here' stub" {
    local f
    f=$(_make_task "## Recommendation
[Your recommendation here]")
    run audit_task_placeholders "$f"
    [ "$status" -eq 1 ]
}

@test "audit: detects REQUIRED before stub comment" {
    local f
    f=$(_make_task "## Recommendation
[REQUIRED before fw inception decide]")
    run audit_task_placeholders "$f"
    [ "$status" -eq 1 ]
}

@test "audit: Updates section is exempt (RCA docs can mention pattern)" {
    local f
    f=$(_make_task "## Problem Statement
All clean above.

## Updates

### 2026-01-01 — rca-note
Tasks with Criterion-one-bracket bleed through to review unnoticed.")
    run audit_task_placeholders "$f"
    [ "$status" -eq 0 ]
}

@test "audit: Dialogue Log section is exempt" {
    local f
    f=$(_make_task "## Problem Statement
Clean.

## Dialogue Log

### Segment 1
Human said: bracket-Criterion-digit-bracket is confusing.")
    run audit_task_placeholders "$f"
    [ "$status" -eq 0 ]
}

@test "audit: fenced code block is exempt" {
    local f
    f=$(_make_task "## Context
Here is the pattern we detect:

\`\`\`
[Criterion 1]
[TODO]
\`\`\`

## Recommendation
GO")
    run audit_task_placeholders "$f"
    [ "$status" -eq 0 ]
}

@test "audit: multiple placeholders reported together" {
    local f
    f=$(_make_task "## Go/No-Go Criteria
- [Criterion 1]
- [Criterion 2]
- [TODO]")
    run audit_task_placeholders "$f"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Criterion 1" ]]
    [[ "$output" =~ "Criterion 2" ]]
    [[ "$output" =~ "TODO" ]]
}

@test "audit: missing file returns 2" {
    run audit_task_placeholders "$TEST_TEMP_DIR/nonexistent.md"
    [ "$status" -eq 2 ]
}

@test "audit: empty arg returns 2" {
    run audit_task_placeholders ""
    [ "$status" -eq 2 ]
}

@test "audit: Criterion 10 (double-digit) also detected" {
    local f
    f=$(_make_task "## Go/No-Go
- [Criterion 10]")
    run audit_task_placeholders "$f"
    [ "$status" -eq 1 ]
}
