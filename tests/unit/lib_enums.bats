#!/usr/bin/env bats
# Unit tests for lib/enums.sh
#
# Tests validation functions: is_valid_status, is_valid_type,
# is_valid_horizon, is_valid_transition, valid_transitions_for

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT

    # Reset guard to allow re-sourcing
    unset _FW_ENUMS_LOADED
    source "$FRAMEWORK_ROOT/lib/enums.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- is_valid_status ---

@test "enums: captured is valid status" {
    run is_valid_status "captured"
    [ "$status" -eq 0 ]
}

@test "enums: started-work is valid status" {
    run is_valid_status "started-work"
    [ "$status" -eq 0 ]
}

@test "enums: work-completed is valid status" {
    run is_valid_status "work-completed"
    [ "$status" -eq 0 ]
}

@test "enums: issues is valid status" {
    run is_valid_status "issues"
    [ "$status" -eq 0 ]
}

@test "enums: invalid status rejected" {
    run is_valid_status "banana"
    [ "$status" -eq 1 ]
}

# --- is_valid_type ---

@test "enums: build is valid type" {
    run is_valid_type "build"
    [ "$status" -eq 0 ]
}

@test "enums: inception is valid type" {
    run is_valid_type "inception"
    [ "$status" -eq 0 ]
}

@test "enums: test is valid type" {
    run is_valid_type "test"
    [ "$status" -eq 0 ]
}

@test "enums: invalid type rejected" {
    run is_valid_type "deploy"
    [ "$status" -eq 1 ]
}

# --- is_valid_horizon ---

@test "enums: now is valid horizon" {
    run is_valid_horizon "now"
    [ "$status" -eq 0 ]
}

@test "enums: next is valid horizon" {
    run is_valid_horizon "next"
    [ "$status" -eq 0 ]
}

@test "enums: later is valid horizon" {
    run is_valid_horizon "later"
    [ "$status" -eq 0 ]
}

@test "enums: invalid horizon rejected" {
    run is_valid_horizon "eventually"
    [ "$status" -eq 1 ]
}

# --- is_recognized_status (includes legacy) ---

@test "enums: refined is recognized (legacy)" {
    run is_recognized_status "refined"
    [ "$status" -eq 0 ]
}

@test "enums: blocked is recognized (legacy)" {
    run is_recognized_status "blocked"
    [ "$status" -eq 0 ]
}

# --- is_valid_transition ---

@test "enums: valid_transitions_for returns targets for started-work" {
    result=$(valid_transitions_for "started-work")
    [[ "$result" == *"issues"* ]]
    [[ "$result" == *"work-completed"* ]]
}

@test "enums: valid_transitions_for returns targets for issues" {
    result=$(valid_transitions_for "issues")
    [[ "$result" == *"started-work"* ]]
}

@test "enums: VALID_TRANSITIONS array is populated" {
    [ "${#VALID_TRANSITIONS[@]}" -gt 0 ]
}

@test "enums: transition array contains captured:started-work" {
    local found=0
    for t in "${VALID_TRANSITIONS[@]}"; do
        [[ "$t" == "captured:started-work" ]] && found=1
    done
    [ "$found" -eq 1 ]
}

# --- valid_transitions_for ---

@test "enums: transitions for started-work include work-completed" {
    result=$(valid_transitions_for "started-work")
    [[ "$result" == *"work-completed"* ]]
}

@test "enums: transitions for captured include started-work" {
    result=$(valid_transitions_for "captured")
    [[ "$result" == *"started-work"* ]]
}

# --- list helpers ---

@test "enums: list_valid_statuses returns all statuses" {
    result=$(list_valid_statuses)
    [[ "$result" == *"captured"* ]]
    [[ "$result" == *"started-work"* ]]
    [[ "$result" == *"work-completed"* ]]
}

@test "enums: list_valid_types returns all types" {
    result=$(list_valid_types)
    [[ "$result" == *"build"* ]]
    [[ "$result" == *"inception"* ]]
}
