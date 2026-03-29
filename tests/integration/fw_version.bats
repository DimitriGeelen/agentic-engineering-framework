#!/usr/bin/env bats
# Integration tests for fw version subcommand
#
# Tests the CLI output for version information:
#   fw version         — show version string, framework root, project root
#   fw --version       — alias for version
#   fw -v              — alias for version

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    mkdir -p "$PROJECT_ROOT/.context"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Basic output ---

@test "fw version: shows version string" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' version"
    [[ "$output" == *"fw v"* ]]
}

@test "fw version: shows framework root path" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' version"
    [[ "$output" == *"Framework:"* ]]
}

@test "fw version: shows project root path" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' version"
    [[ "$output" == *"Project:"* ]]
}

@test "fw version: version string matches semver pattern" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' version"
    local version_line
    version_line=$(echo "$output" | head -1)
    [[ "$version_line" =~ fw\ v[0-9]+\.[0-9]+\.[0-9]+ ]]
}

# --- Aliases ---

@test "fw --version: works as alias" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' --version"
    [[ "$output" == *"fw v"* ]]
}

@test "fw -v: works as alias" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' -v"
    [[ "$output" == *"fw v"* ]]
}
