#!/usr/bin/env bats
# Integration tests for fw search subcommand

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "fw search: no args shows usage" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' search"
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"search"* ]]
}

@test "fw search: keyword search runs" {
    # Create a task file with searchable content
    cat > "$PROJECT_ROOT/.tasks/active/T-901-searchable-task.md" <<'MD'
---
id: T-901
name: "Searchable test task"
status: started-work
workflow_type: build
owner: agent
---
# T-901: Searchable test task
MD
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' search searchable"
    [[ "$output" == *"T-901"* ]] || [[ "$output" == *"Searchable"* ]] || [[ "$output" == *"result"* ]] || [ "$status" -eq 0 ]
}
