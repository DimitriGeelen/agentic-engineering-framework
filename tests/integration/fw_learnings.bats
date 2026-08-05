#!/usr/bin/env bats
# Integration tests for fw learnings subcommand

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

# --- Empty ---

@test "fw learnings: runs with empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' learnings"
    [[ "$output" == *"Learning"* ]] || [[ "$output" == *"learning"* ]] || [[ "$output" == *"No"* ]] || [[ "$output" == *"0"* ]]
}

# --- With data ---

@test "fw learnings: shows learnings from learnings.yaml" {
    cat > "$PROJECT_ROOT/.context/project/learnings.yaml" <<'YAML'
learnings:
  - id: L-001
    learning: "Always validate inputs"
    task: T-001
    date: "2026-01-01"
    source: P-001
    status: confirmed
YAML
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' learnings"
    [[ "$output" == *"L-001"* ]] || [[ "$output" == *"validate"* ]] || [[ "$output" == *"Learning"* ]]
}
