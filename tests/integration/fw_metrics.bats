#!/usr/bin/env bats
# Integration tests for fw metrics subcommand
#
# Tests the CLI interface for framework metrics:
#   fw metrics            — show metrics dashboard
#   fw metrics dashboard  — same as above
#   fw metrics predict    — effort prediction

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

# --- Dashboard ---

@test "fw metrics: shows metrics dashboard" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' metrics"
    [ "$status" -eq 0 ]
    [[ "$output" == *"METRICS"* ]] || [[ "$output" == *"metrics"* ]] || [[ "$output" == *"TASK"* ]]
}

@test "fw metrics: shows task counts" {
    # Create a task so counts are non-zero
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' task create --name 'Metrics count test' --type build --owner agent --description 'Test'" > /dev/null 2>&1
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' metrics"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Active"* ]] || [[ "$output" == *"active"* ]] || [[ "$output" == *"1"* ]]
}

@test "fw metrics dashboard: same as bare metrics" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' metrics dashboard"
    [ "$status" -eq 0 ]
    [[ "$output" == *"METRICS"* ]] || [[ "$output" == *"TASK"* ]]
}

# --- Predict ---

@test "fw metrics predict: shows effort prediction" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' metrics predict --type build"
    [ "$status" -eq 0 ]
    [[ "$output" == *"predict"* ]] || [[ "$output" == *"Predict"* ]] || [[ "$output" == *"build"* ]] || [[ "$output" == *"effort"* ]] || [[ "$output" == *"episodic"* ]]
}
