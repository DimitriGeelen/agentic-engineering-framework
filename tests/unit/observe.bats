#!/usr/bin/env bats
# Unit tests for agents/observe/observe.sh (fw note)
# Origin: T-932, T-943 (isolation fix)

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
OBSERVE="$FRAMEWORK_ROOT/agents/observe/observe.sh"

# Isolate capture tests from real inbox
setup() {
    export TEST_DIR="$(mktemp -d)"
    mkdir -p "$TEST_DIR/.context/working"
    # Create a minimal focus.yaml so get_focus_task works
    echo 'current_task: T-001' > "$TEST_DIR/.context/working/focus.yaml"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# --- Help ---

@test "observe --help shows usage" {
    run "$OBSERVE" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw note"* ]]
    [[ "$output" == *"observation"* ]] || [[ "$output" == *"capture"* ]]
}

@test "observe -h shows usage" {
    run "$OBSERVE" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw note"* ]]
}

# --- Count ---

@test "observe count shows pending count" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" count
    [ "$status" -eq 0 ]
    [[ "$output" == *"pending"* ]] || [[ "$output" =~ [0-9]+ ]]
}

# --- List ---

@test "observe list runs without error" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" list
    [ "$status" -eq 0 ]
}

# --- Capture (isolated) ---

@test "observe captures a note" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" "Test observation from bats"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OBS-"* ]] || [[ "$output" == *"Captured"* ]] || [[ "$output" == *"observation"* ]]
    # Verify it went to temp dir, not real inbox
    [ -f "$TEST_DIR/.context/inbox.yaml" ]
}

@test "observe captures with --tag" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" "Tagged observation" --tag "test"
    [ "$status" -eq 0 ]
}

# --- Empty input ---

@test "observe fails with empty text" {
    export PROJECT_ROOT="$TEST_DIR"
    run "$OBSERVE" ""
    # Should fail or show help
    [ "$status" -ne 0 ] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"fw note"* ]]
}
