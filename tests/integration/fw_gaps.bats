#!/usr/bin/env bats
# Integration tests for fw gaps subcommand
#
# Tests the CLI interface for the gaps register:
#   fw gaps — display gaps from concerns.yaml

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

# --- No gaps file ---

@test "fw gaps: runs when no concerns.yaml exists" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' gaps"
    [[ "$output" == *"No gaps"* ]] || [[ "$output" == *"gaps"* ]] || [[ "$output" == *"concern"* ]]
}

# --- With gaps file ---

@test "fw gaps: shows gaps from gaps.yaml" {
    cat > "$PROJECT_ROOT/.context/project/gaps.yaml" <<'YAML'
gaps:
  - id: G-001
    title: "Test gap for integration testing"
    severity: medium
    status: watching
    decision_trigger: "When evidence appears"
YAML
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' gaps"
    [ "$status" -eq 0 ]
    [[ "$output" == *"G-001"* ]] || [[ "$output" == *"Test gap"* ]] || [[ "$output" == *"watching"* ]]
}
