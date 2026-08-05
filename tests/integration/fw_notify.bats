#!/usr/bin/env bats
# Integration tests for fw notify subcommand (T-710)
#
# Tests the CLI interface for push notification management:
#   fw notify status    — show config state
#   fw notify enable    — set enabled=true
#   fw notify disable   — set enabled=false
#   fw notify setup     — prerequisite check and guide
#   fw notify test      — send test (requires enabled)
#   fw notify           — show help

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.context"
    # Create minimal .framework.yaml so fw resolves PROJECT_ROOT
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Help ---

@test "fw notify: no subcommand shows help" {
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"status"* ]]
    [[ "$output" == *"enable"* ]]
    [[ "$output" == *"disable"* ]]
}

@test "fw notify --help: shows help" {
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify --help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

# --- Status ---

@test "fw notify status: shows disabled when no config" {
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"false"* ]]
}

@test "fw notify status: shows enabled after enable" {
    bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify enable" > /dev/null
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"true"* ]]
}

# --- Enable/Disable ---

@test "fw notify enable: creates config file" {
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify enable"
    [ "$status" -eq 0 ]
    [ -f "$PROJECT_ROOT/.context/notify-config.yaml" ]
    [[ "$output" == *"enabled"* ]]
}

@test "fw notify disable: sets enabled to false" {
    bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify enable" > /dev/null
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify disable"
    [ "$status" -eq 0 ]
    [[ "$output" == *"disabled"* ]]
    # Verify config file says false
    local val
    val=$(python3 -c "import yaml; print(str(yaml.safe_load(open('$PROJECT_ROOT/.context/notify-config.yaml')).get('enabled','?')).lower())")
    [ "$val" = "false" ]
}

@test "fw notify enable then disable then enable: toggles correctly" {
    bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify enable" > /dev/null
    bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify disable" > /dev/null
    bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify enable" > /dev/null
    local val
    val=$(python3 -c "import yaml; print(str(yaml.safe_load(open('$PROJECT_ROOT/.context/notify-config.yaml')).get('enabled','?')).lower())")
    [ "$val" = "true" ]
}

# --- Test (requires enabled) ---

@test "fw notify test: fails when disabled" {
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify test"
    [ "$status" -eq 1 ]
    [[ "$output" == *"disabled"* ]]
}

# --- Invalid subcommand ---

@test "fw notify badcmd: fails with error" {
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify badcmd"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown"* ]]
}

# --- Setup ---

@test "fw notify setup: shows prerequisites" {
    run bash -c "PROJECT_ROOT='$PROJECT_ROOT' '$FW' notify setup"
    # May exit 0 or 1 depending on dispatcher availability
    [[ "$output" == *"Notification Setup"* ]]
    [[ "$output" == *"Prerequisites"* ]]
}
