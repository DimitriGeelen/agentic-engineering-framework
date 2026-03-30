#!/usr/bin/env bats
# Unit tests for lib/errors.sh
#
# Tests die, error, warn, info, success, block output functions

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export NO_COLOR=1  # Disable colors for clean output matching

    # Reset guard to allow re-sourcing
    unset _FW_ERRORS_LOADED _FW_COLORS_LOADED
    source "$FRAMEWORK_ROOT/lib/errors.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- error ---

@test "errors: error outputs ERROR prefix to stderr" {
    run error "something broke"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ERROR: something broke"* ]]
}

# --- warn ---

@test "errors: warn outputs WARNING prefix" {
    run warn "be careful"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING: be careful"* ]]
}

# --- info ---

@test "errors: info outputs message" {
    run info "informational message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"informational message"* ]]
}

# --- success ---

@test "errors: success outputs message" {
    run success "it worked"
    [ "$status" -eq 0 ]
    [[ "$output" == *"it worked"* ]]
}

# --- die ---

@test "errors: die exits with code 1 by default" {
    run die "fatal error"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: fatal error"* ]]
}

@test "errors: die exits with custom code" {
    run die "custom exit" 42
    [ "$status" -eq 42 ]
    [[ "$output" == *"ERROR: custom exit"* ]]
}

# --- block ---

@test "errors: block exits with code 2" {
    run block "action blocked"
    [ "$status" -eq 2 ]
    [[ "$output" == *"BLOCKED: action blocked"* ]]
}

@test "errors: block includes message" {
    run block "task gate denied"
    [[ "$output" == *"task gate denied"* ]]
}

# --- edge cases ---

@test "errors: error with empty message" {
    run error ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"ERROR:"* ]]
}

@test "errors: warn with special characters" {
    run warn "path /foo/bar has 'quotes'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING:"* ]]
}

@test "errors: info with multiword message" {
    run info "this is a long info message with spaces"
    [ "$status" -eq 0 ]
    [[ "$output" == *"this is a long info message with spaces"* ]]
}
