#!/usr/bin/env bats
# Unit tests for agents/git/lib/common.sh
#
# Tests pure functions: extract_task_id, task_exists, get_task_name

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" "$PROJECT_ROOT/.context"
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    export CONTEXT_DIR="$PROJECT_ROOT/.context"
    RED='' GREEN='' YELLOW='' CYAN='' BLUE='' NC=''
    # Source dependencies that git.sh normally provides
    source "$FRAMEWORK_ROOT/lib/compat.sh"
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
    source "$FRAMEWORK_ROOT/agents/git/lib/common.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- extract_task_id ---

@test "extract_task_id: extracts T-NNN from commit message" {
    result=$(extract_task_id "T-042: Fix login bug")
    [ "$result" = "T-042" ]
}

@test "extract_task_id: extracts first T-NNN when multiple present" {
    result=$(extract_task_id "T-042: refs T-099")
    [ "$result" = "T-042" ]
}

@test "extract_task_id: returns empty for message without task ref" {
    result=$(extract_task_id "Fix login bug")
    [ -z "$result" ]
}

@test "extract_task_id: handles T-NNN at end of message" {
    result=$(extract_task_id "Some work for T-007")
    [ "$result" = "T-007" ]
}

@test "extract_task_id: handles three-digit task IDs" {
    result=$(extract_task_id "T-159: Test infrastructure")
    [ "$result" = "T-159" ]
}

# --- task_exists ---

@test "task_exists: returns true for active task" {
    touch "$PROJECT_ROOT/.tasks/active/T-042-fix-login.md"
    task_exists "T-042"
}

@test "task_exists: returns true for completed task" {
    touch "$PROJECT_ROOT/.tasks/completed/T-042-fix-login.md"
    task_exists "T-042"
}

@test "task_exists: returns false for nonexistent task" {
    ! task_exists "T-999"
}

# --- get_task_name ---

@test "get_task_name: returns name from frontmatter" {
    cat > "$PROJECT_ROOT/.tasks/active/T-042-fix-login.md" <<'EOF'
---
id: T-042
name: "Fix login bug"
status: started-work
---
EOF
    # lib/tasks.sh get_task_name strips surrounding quotes
    result=$(get_task_name "T-042")
    [ "$result" = 'Fix login bug' ]
}

@test "get_task_name: returns empty for nonexistent task" {
    run get_task_name "T-999"
    [ -z "$output" ]
}
