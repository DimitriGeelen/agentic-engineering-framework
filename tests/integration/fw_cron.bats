#!/usr/bin/env bats
# Integration tests for fw cron subcommand
#
# Tests the CLI interface for cron job management:
#   fw cron status     — show registry status
#   fw cron list       — alias for status
#   fw cron generate   — regenerate crontab from registry
#   fw cron run <id>   — run a job immediately
#   fw cron pause <id> — pause a job
#   fw cron resume <id> — resume a paused job

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.context"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    # Copy cron registry so status/list work
    if [ -f "$FRAMEWORK_ROOT/.context/cron-registry.yaml" ]; then
        cp "$FRAMEWORK_ROOT/.context/cron-registry.yaml" "$PROJECT_ROOT/.context/"
    fi
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Help ---

@test "fw cron: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' cron"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"status"* ]]
}

@test "fw cron --help: shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' cron --help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"status"* ]]
}

# --- Status ---

@test "fw cron status: shows registry info" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' cron status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cron registry"* ]] || [[ "$output" == *"jobs"* ]]
}

@test "fw cron status: shows job count" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' cron status"
    [ "$status" -eq 0 ]
    [[ "$output" == *"active"* ]]
}

# --- List (alias for status) ---

@test "fw cron list: works as status alias" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' cron list"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cron registry"* ]] || [[ "$output" == *"jobs"* ]]
}

# --- Invalid subcommand ---

@test "fw cron badcmd: fails with error" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' cron badcmd"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"unknown"* ]] || [[ "$output" == *"Usage"* ]]
}

# --- Run ---

@test "fw cron run: without job-id shows error" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' cron run"
    [ "$status" -ne 0 ]
}

# --- Pause/Resume ---

@test "fw cron pause: without job-id shows error" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' cron pause"
    [ "$status" -ne 0 ]
}

@test "fw cron resume: without job-id shows error" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' cron resume"
    [ "$status" -ne 0 ]
}
