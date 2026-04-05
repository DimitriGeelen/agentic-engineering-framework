#!/usr/bin/env bats
# Integration tests for fw config subcommand
# Origin: T-927

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    export TEST_DIR="$(mktemp -d)"
    cat > "$TEST_DIR/.framework.yaml" << 'EOF'
project_name: test-integration
version: 1.0.0
provider: claude-code
EOF
    export PROJECT_ROOT="$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# --- Help ---

@test "fw config: shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' config help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw config"* ]]
    [[ "$output" == *"set"* ]]
    [[ "$output" == *"get"* ]]
    [[ "$output" == *"list"* ]]
}

@test "fw config: --help flag works" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' config --help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw config"* ]]
}

# --- List ---

@test "fw config list: shows project settings" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$TEST_DIR' '$FW' config list"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-integration"* ]] || [[ "$output" == *"project_name"* ]]
}

# --- Get ---

@test "fw config get: reads project_name" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$TEST_DIR' '$FW' config get project_name"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-integration"* ]]
}

@test "fw config get: fails for missing key" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' config get NONEXISTENT_KEY_12345"
    [ "$status" -ne 0 ]
}

@test "fw config get: fails without key" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' config get"
    [ "$status" -ne 0 ]
}

# --- Overrides ---

@test "fw config overrides: shows active overrides header" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' config overrides"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Overrides"* ]]
}

@test "fw config overrides: detects env override" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' FW_PORT=9999 '$FW' config overrides"
    [ "$status" -eq 0 ]
    [[ "$output" == *"9999"* ]]
    [[ "$output" == *"env"* ]]
}

# --- Unknown subcommand ---

@test "fw config: unknown subcommand fails" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' config nonexistent"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown"* ]]
}
