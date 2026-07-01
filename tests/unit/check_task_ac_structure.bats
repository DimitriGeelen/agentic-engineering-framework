#!/usr/bin/env bats
# T-2420: check-task-ac-structure PreToolUse hook — unit tests.
#
# Covers:
#   - ### Human outside ## Acceptance Criteria blocks (new malformation)
#   - Grandfather logic (no-worse-than: existing malformation passes)
#   - Correct structure passes
#   - Override via FW_ALLOW_AC_STRUCTURE_DRIFT=1
#   - Agent-vs-human control (CLAUDECODE=1 blocks, unset is advisory)
#   - Pass-through for non-task files, non-matching tools
#   - Edit and MultiEdit synthetic paths

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-/opt/999-Agentic-Engineering-Framework}"
    HOOK_SH="$FRAMEWORK_ROOT/agents/context/check-task-ac-structure.sh"
    HOOK_PY="$FRAMEWORK_ROOT/agents/context/check-task-ac-structure.py"
    [ -f "$HOOK_SH" ] || skip "hook .sh wrapper not found"
    [ -f "$HOOK_PY" ] || skip "hook .py implementation not found"

    TEST_ROOT="$(mktemp -d)"
    mkdir -p "$TEST_ROOT/.tasks/active" "$TEST_ROOT/.tasks/completed" "$TEST_ROOT/.context/working"

    export PROJECT_ROOT="$TEST_ROOT"
    export CLAUDECODE=1
    unset FW_ALLOW_AC_STRUCTURE_DRIFT
}

teardown() {
    rm -rf "$TEST_ROOT" 2>/dev/null
}

# ── helpers ───────────────────────────────────────────────────────────────────

run_hook_write() {
    local file="$1" content="$2"
    local input
    input=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Write', 'tool_input': {'file_path': sys.argv[1], 'content': sys.argv[2]}}))
" "$file" "$content")
    run bash "$HOOK_SH" <<< "$input"
}

run_hook_edit() {
    local file="$1" old_str="$2" new_str="$3"
    local input
    input=$(python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Edit', 'tool_input': {
    'file_path': sys.argv[1],
    'old_string': sys.argv[2],
    'new_string': sys.argv[3],
    'replace_all': False
}}))
" "$file" "$old_str" "$new_str")
    run bash "$HOOK_SH" <<< "$input"
}

# ── pass-through cases ────────────────────────────────────────────────────────

@test "T-2420: correct AC structure passes" {
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
name: test
---
## Acceptance Criteria

### Agent
- [ ] AC 1

### Human
- [ ] Human AC 1

## Next Section
body"
    run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
}

@test "T-2420: no Human heading passes" {
    local file="$TEST_ROOT/.tasks/active/T-9990-test.md"
    local content="---
id: T-9990
---
## Acceptance Criteria

### Agent
- [ ] AC 1

## Next Section"
    run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
}

@test "T-2420: non-task file passes through" {
    local file="$TEST_ROOT/regular-file.md"
    local content="### Human
This is not a task file"
    run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
}

# ── malformation detection ────────────────────────────────────────────────────

@test "T-2420: introducing malformed Human heading blocks (CLAUDECODE=1)" {
    local file="$TEST_ROOT/.tasks/active/T-9991-test.md"
    # Start clean
    local old_content="---
id: T-9991
---
## Acceptance Criteria

### Agent
- [ ] AC 1

## Next Section
body"
    echo "$old_content" > "$file"

    # Try to insert ## Build after Agent but before a malformed ### Human
    local new_content="---
id: T-9991
---
## Acceptance Criteria

### Agent
- [ ] AC 1

## Build Summary
build notes

### Human
- [ ] Human AC lost

## Next Section
body"
    
    run_hook_write "$file" "$new_content"
    [ "$status" -eq 2 ]
    [[ "$output" == *"TASK AC STRUCTURE ERROR"* ]]
    [[ "$output" == *"T-9991"* ]]
    [[ "$output" == *"Old count: 0"* ]]
    [[ "$output" == *"New count: 1"* ]]
}

@test "T-2420: override allows malformed structure with log" {
    export FW_ALLOW_AC_STRUCTURE_DRIFT=1
    local file="$TEST_ROOT/.tasks/active/T-9992-test.md"
    local content="---
id: T-9992
---
## Acceptance Criteria

### Agent
- [ ] AC

## Intervening Section

### Human
- [ ] Lost AC"

    run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
    [[ "$output" == *"FW_ALLOW_AC_STRUCTURE_DRIFT=1"* ]]
    
    # Check log entry
    [ -f "$TEST_ROOT/.context/working/.gate-bypass-log.yaml" ]
    grep -q "FW_ALLOW_AC_STRUCTURE_DRIFT" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
    grep -q "T-9992" "$TEST_ROOT/.context/working/.gate-bypass-log.yaml"
}

# ── grandfather logic ──────────────────────────────────────────────────────────

@test "T-2420: fixing malformation (decreasing count) passes" {
    local file="$TEST_ROOT/.tasks/active/T-9993-test.md"
    # Start with 2 malformed Human headings
    local old_content="---
id: T-9993
---
## Acceptance Criteria

### Agent
- [ ] AC

## Section 1

### Human
- [ ] Lost AC 1

## Section 2

### Human
- [ ] Lost AC 2"
    echo "$old_content" > "$file"

    # Fix one of them by moving it back inside AC block
    local new_content="---
id: T-9993
---
## Acceptance Criteria

### Agent
- [ ] AC

### Human
- [ ] Fixed AC 1

## Section 1

## Section 2

### Human
- [ ] Lost AC 2"
    
    run_hook_write "$file" "$new_content"
    [ "$status" -eq 0 ]
}

@test "T-2420: preserving existing malformation (same count) passes" {
    local file="$TEST_ROOT/.tasks/active/T-9994-test.md"
    # Start with 1 malformed Human heading
    local old_content="---
id: T-9994
---
## Acceptance Criteria

### Agent
- [ ] AC

## Section

### Human
- [ ] Lost AC"
    echo "$old_content" > "$file"

    # Edit something else, keep same structure
    run_hook_edit "$file" "### Agent" "### Agent
- [ ] Another AC"
    
    [ "$status" -eq 0 ]
}

@test "T-2420: worsening malformation (increasing count) blocks" {
    local file="$TEST_ROOT/.tasks/active/T-9995-test.md"
    # Start with 1 malformed
    local old_content="---
id: T-9995
---
## Section 1

### Human
- [ ] Lost AC 1"
    echo "$old_content" > "$file"

    # Add another malformed one
    local new_content="---
id: T-9995
---
## Section 1

### Human
- [ ] Lost AC 1

## Section 2

### Human
- [ ] Lost AC 2"
    
    run_hook_write "$file" "$new_content"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Old count: 1"* ]]
    [[ "$output" == *"New count: 2"* ]]
}

# ── agent vs human control ─────────────────────────────────────────────────────

@test "T-2420: malformation advisory when not under agent control" {
    unset CLAUDECODE
    local file="$TEST_ROOT/.tasks/active/T-9996-test.md"
    local content="---
id: T-9996
---
## Section

### Human
- [ ] Lost"

    run_hook_write "$file" "$content"
    [ "$status" -eq 0 ]
    [[ "$output" == *"would block under agent control"* ]]
    [[ "$output" == *"T-9996"* ]]
}

# ── tool variants ──────────────────────────────────────────────────────────────

@test "T-2420: Edit tool detects malformation" {
    local file="$TEST_ROOT/.tasks/active/T-9997-test.md"
    local old_content="---
id: T-9997
---
## Acceptance Criteria

### Agent
- [ ] AC

## Next"
    echo "$old_content" > "$file"

    # Edit to introduce malformed Human heading
    run_hook_edit "$file" "## Next" "## Next

### Human
- [ ] Lost AC"
    
    [ "$status" -eq 2 ]
    [[ "$output" == *"TASK AC STRUCTURE ERROR"* ]]
}

