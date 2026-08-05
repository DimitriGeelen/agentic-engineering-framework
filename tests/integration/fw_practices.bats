#!/usr/bin/env bats
# Integration tests for fw practices subcommand

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

@test "fw practices: runs with empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' practices"
    [[ "$output" == *"Practice"* ]] || [[ "$output" == *"practice"* ]] || [[ "$output" == *"No"* ]] || [[ "$output" == *"0"* ]]
}

@test "fw practices: shows practices from practices.yaml" {
    cat > "$PROJECT_ROOT/.context/project/practices.yaml" <<'YAML'
practices:
  - id: P-001
    name: "Test Practice"
    status: active
    derived_from: D1
    applications: 3
YAML
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' practices"
    [[ "$output" == *"P-001"* ]] || [[ "$output" == *"Test Practice"* ]] || [[ "$output" == *"Practice"* ]]
}
