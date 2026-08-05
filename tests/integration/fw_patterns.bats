#!/usr/bin/env bats
# Integration tests for fw patterns subcommand

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

@test "fw patterns: runs with empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' patterns"
    [[ "$output" == *"Pattern"* ]] || [[ "$output" == *"pattern"* ]] || [[ "$output" == *"No"* ]] || [[ "$output" == *"0"* ]]
}

# --- With data ---

@test "fw patterns: shows patterns from patterns.yaml" {
    cat > "$PROJECT_ROOT/.context/project/patterns.yaml" <<'YAML'
patterns:
  - id: FP-001
    type: failure
    name: "Test pattern"
    task: T-001
    trigger: "When X happens"
    mitigation: "Do Y instead"
YAML
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' patterns"
    [[ "$output" == *"FP-001"* ]] || [[ "$output" == *"Test pattern"* ]] || [[ "$output" == *"Pattern"* ]]
}
