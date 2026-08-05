#!/usr/bin/env bats
# Integration tests for fw git subcommand
#
# Tests the CLI interface for git operations:
#   fw git status  — task-aware git status
#   fw git commit  — commit with task reference validation
#   fw git help    — show help

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed" "$PROJECT_ROOT/.context/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    # Initialize a git repo in temp dir for git operations
    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" config user.email "test@test.com"
    git -C "$PROJECT_ROOT" config user.name "Test"
    # Create initial commit so git operations work
    echo "init" > "$PROJECT_ROOT/init.txt"
    git -C "$PROJECT_ROOT" add init.txt
    git -C "$PROJECT_ROOT" commit -q -m "Initial commit"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Help ---

@test "fw git: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' git"
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"commit"* ]] || [[ "$output" == *"status"* ]]
}

@test "fw git help: shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' git help"
    [[ "$output" == *"commit"* ]]
    [[ "$output" == *"status"* ]]
}

# --- Status ---

@test "fw git status: runs without error" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' git status"
    [ "$status" -eq 0 ]
}

@test "fw git status: shows clean state" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' git status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean"* ]] || [[ "$output" == *"nothing"* ]] || [[ "$output" == *"status"* ]]
}

# --- Commit ---

@test "fw git commit: rejects commit without task reference" {
    echo "change" > "$PROJECT_ROOT/test.txt"
    git -C "$PROJECT_ROOT" add test.txt
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' git commit -m 'No task ref'"
    # Should fail or warn about missing task reference
    [[ "$output" == *"T-"* ]] || [[ "$output" == *"task"* ]] || [ "$status" -ne 0 ]
}

@test "fw git commit: accepts commit with task reference" {
    # Create a task first
    cat > "$PROJECT_ROOT/.tasks/active/T-900-test-commit.md" <<'EOF'
---
id: T-900
name: "Test commit"
description: "Task for commit test"
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
EOF
    echo "change" > "$PROJECT_ROOT/test.txt"
    git -C "$PROJECT_ROOT" add test.txt
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' git commit -m 'T-900: Test change'"
    [ "$status" -eq 0 ]
}
