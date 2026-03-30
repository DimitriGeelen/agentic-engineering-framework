#!/usr/bin/env bats
# Unit tests for lib/tasks.sh
#
# Tests find_task_file(), task_exists(), get_task_name()

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FRAMEWORK_ROOT
    export TASKS_DIR="$PROJECT_ROOT/.tasks"
    mkdir -p "$TASKS_DIR/active" "$TASKS_DIR/completed"

    # Reset guard to allow re-sourcing
    unset _FW_TASKS_LOADED
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- find_task_file ---

@test "find_task_file: finds task in active" {
    touch "$TASKS_DIR/active/T-100-test-task.md"
    result=$(find_task_file "T-100")
    [[ "$result" == *"T-100-test-task.md" ]]
}

@test "find_task_file: finds task in completed" {
    touch "$TASKS_DIR/completed/T-200-done-task.md"
    result=$(find_task_file "T-200")
    [[ "$result" == *"T-200-done-task.md" ]]
}

@test "find_task_file: prefers active over completed" {
    touch "$TASKS_DIR/active/T-300-task.md"
    touch "$TASKS_DIR/completed/T-300-task.md"
    result=$(find_task_file "T-300")
    [[ "$result" == *"active"* ]]
}

@test "find_task_file: returns empty for nonexistent task" {
    run find_task_file "T-999"
    [ -z "$output" ]
}

@test "find_task_file: scoped search only checks specified dir" {
    touch "$TASKS_DIR/completed/T-400-done.md"
    run find_task_file "T-400" "active"
    [ -z "$output" ]
    result=$(find_task_file "T-400" "completed")
    [[ "$result" == *"T-400-done.md" ]]
}

# --- task_exists ---

@test "task_exists: returns 0 for existing task" {
    touch "$TASKS_DIR/active/T-500-exists.md"
    run task_exists "T-500"
    [ "$status" -eq 0 ]
}

@test "task_exists: returns 1 for missing task" {
    run task_exists "T-888"
    [ "$status" -eq 1 ]
}

# --- get_task_name ---

@test "get_task_name: extracts name from task file" {
    cat > "$TASKS_DIR/active/T-600-named.md" << 'EOF'
---
id: T-600
name: "My Important Task"
status: started-work
---
EOF
    result=$(get_task_name "T-600")
    [ "$result" = "My Important Task" ]
}

@test "get_task_name: extracts unquoted name" {
    cat > "$TASKS_DIR/active/T-601-unquoted.md" << 'EOF'
---
id: T-601
name: Simple task name
status: captured
---
EOF
    result=$(get_task_name "T-601")
    [ "$result" = "Simple task name" ]
}

@test "get_task_name: returns empty for nonexistent task" {
    run get_task_name "T-999"
    [ -z "$output" ]
}
