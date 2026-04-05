#!/usr/bin/env bats
# Unit tests for agents/observe/observe.sh (fw note)
# Origin: T-932

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
OBSERVE="$FRAMEWORK_ROOT/agents/observe/observe.sh"

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
    run "$OBSERVE" count
    [ "$status" -eq 0 ]
    [[ "$output" == *"pending"* ]] || [[ "$output" =~ [0-9]+ ]]
}

# --- List ---

@test "observe list runs without error" {
    run "$OBSERVE" list
    [ "$status" -eq 0 ]
}

# --- Capture ---

@test "observe captures a note" {
    run "$OBSERVE" "Test observation from bats"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OBS-"* ]] || [[ "$output" == *"Captured"* ]] || [[ "$output" == *"observation"* ]]
}

@test "observe captures with --tag" {
    run "$OBSERVE" "Tagged observation" --tag "test"
    [ "$status" -eq 0 ]
}

# --- Empty input ---

@test "observe fails with empty text" {
    run "$OBSERVE" ""
    # Should fail or show help
    [ "$status" -ne 0 ] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"fw note"* ]]
}
