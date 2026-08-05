#!/usr/bin/env bats
# Unit tests for agents/context/lib/learning.sh
#
# Tests the do_add_learning() function:
#   - Argument parsing (learning text, --task, --source)
#   - Error handling (missing text)
#   - ID generation (L-XXX or PL-XXX)
#   - File creation and appending
#   - Output formatting

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"

    # Disable colors for test output matching
    RED='' GREEN='' YELLOW='' CYAN='' NC=''

    # Stub ensure_context_dirs
    ensure_context_dirs() { mkdir -p "$CONTEXT_DIR/working" "$CONTEXT_DIR/project"; }
    export -f ensure_context_dirs

    # Source dependencies
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    source "$FRAMEWORK_ROOT/lib/compat.sh"
    source "$FRAMEWORK_ROOT/agents/context/lib/learning.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Error handling ---

@test "add learning: no text shows error" {
    run do_add_learning
    [ "$status" -eq 1 ]
    [[ "$output" == *"Learning text required"* ]]
}

@test "add learning: unknown option shows error" {
    run do_add_learning --badopt value
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

# --- File creation ---

@test "add learning: creates learnings.yaml when missing" {
    rm -f "$CONTEXT_DIR/project/learnings.yaml"
    run do_add_learning "Test learning"
    [ "$status" -eq 0 ]
    [ -f "$CONTEXT_DIR/project/learnings.yaml" ]
}

@test "add learning: creates first entry with L-001 ID in framework project" {
    # T-1258: DO NOT set PROJECT_ROOT=FRAMEWORK_ROOT — it destroys the real
    # learnings.yaml on every test run (observed 4× in April 2026, commits 41264a3a,
    # 5d90f655, 96cd1080, 4eb23e81). Instead, simulate "framework mode" by setting
    # FRAMEWORK_ROOT == PROJECT_ROOT == TEST_TEMP_DIR so the id_prefix=L branch in
    # do_add_learning is taken without touching the real framework.
    local save_framework_root="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT="$TEST_TEMP_DIR"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    mkdir -p "$CONTEXT_DIR/project"
    local learnings_file="$CONTEXT_DIR/project/learnings.yaml"
    rm -f "$learnings_file"
    run do_add_learning "First learning"
    [ "$status" -eq 0 ]
    [[ "$output" == *"L-001"* ]]
    # Restore
    export FRAMEWORK_ROOT="$save_framework_root"
}

# --- ID sequencing ---

@test "add learning: second entry increments ID" {
    rm -f "$CONTEXT_DIR/project/learnings.yaml"
    do_add_learning "First learning"
    run do_add_learning "Second learning"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PL-002"* ]]
    grep -q "id: PL-002" "$CONTEXT_DIR/project/learnings.yaml"
}

# --- Consumer project prefix ---

@test "add learning: uses PL- prefix in consumer project" {
    rm -f "$CONTEXT_DIR/project/learnings.yaml"
    # Set different PROJECT_ROOT and FRAMEWORK_ROOT to simulate consumer project
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FRAMEWORK_ROOT="/some/other/path"
    run do_add_learning "Consumer learning"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PL-001"* ]]
    # Restore for teardown
    export FRAMEWORK_ROOT
}

# --- Optional arguments ---

@test "add learning: includes task reference" {
    rm -f "$CONTEXT_DIR/project/learnings.yaml"
    run do_add_learning "Task learning" --task T-123
    [ "$status" -eq 0 ]
    [[ "$output" == *"Task: T-123"* ]]
    grep -q "task: T-123" "$CONTEXT_DIR/project/learnings.yaml"
}

@test "add learning: includes source reference" {
    rm -f "$CONTEXT_DIR/project/learnings.yaml"
    run do_add_learning "Source learning" --source P-001
    [ "$status" -eq 0 ]
    [[ "$output" == *"Source: P-001"* ]]
    grep -q "source: P-001" "$CONTEXT_DIR/project/learnings.yaml"
}

@test "add learning: stores learning text in file" {
    rm -f "$CONTEXT_DIR/project/learnings.yaml"
    run do_add_learning "Always validate inputs before processing"
    [ "$status" -eq 0 ]
    grep -q "Always validate inputs before processing" "$CONTEXT_DIR/project/learnings.yaml"
}

# --- Output formatting ---

@test "add learning: shows confirmation with learning text" {
    rm -f "$CONTEXT_DIR/project/learnings.yaml"
    run do_add_learning "My test learning"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Learning added"* ]]
    [[ "$output" == *"My test learning"* ]]
}
