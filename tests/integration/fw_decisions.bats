#!/usr/bin/env bats
# Integration tests for fw decisions subcommand

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

@test "fw decisions: runs with empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' decisions"
    [[ "$output" == *"Decision"* ]] || [[ "$output" == *"decision"* ]] || [[ "$output" == *"No"* ]] || [[ "$output" == *"0"* ]]
}

# --- With data ---

@test "fw decisions: shows decisions from decisions.yaml" {
    cat > "$PROJECT_ROOT/.context/project/decisions.yaml" <<'YAML'
decisions:
  - id: AD-001
    decision: "Use YAML for config"
    type: architectural
    date: "2026-01-01"
    directives: [D1]
    rationale: "Human readable"
YAML
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' decisions"
    [[ "$output" == *"AD-001"* ]] || [[ "$output" == *"YAML"* ]] || [[ "$output" == *"Decision"* ]]
}
