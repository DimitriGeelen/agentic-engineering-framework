#!/usr/bin/env bats
# Unit tests for lib/colors.sh
#
# Tests TTY-aware, NO_COLOR-respecting color variable setup

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- NO_COLOR support ---

@test "colors: NO_COLOR disables all color variables" {
    unset _FW_COLORS_LOADED
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    [ -z "$RED" ]
    [ -z "$GREEN" ]
    [ -z "$YELLOW" ]
    [ -z "$NC" ]
}

@test "colors: NO_COLOR sets CYAN to empty" {
    unset _FW_COLORS_LOADED
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    [ -z "$CYAN" ]
}

@test "colors: NO_COLOR sets BOLD to empty" {
    unset _FW_COLORS_LOADED
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    [ -z "$BOLD" ]
}

@test "colors: NO_COLOR sets DIM to empty" {
    unset _FW_COLORS_LOADED
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    [ -z "$DIM" ]
}

# --- Variable existence ---

@test "colors: all expected variables are defined" {
    unset _FW_COLORS_LOADED
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    # Variables should exist (even if empty with NO_COLOR)
    [ "${RED+set}" = "set" ]
    [ "${GREEN+set}" = "set" ]
    [ "${YELLOW+set}" = "set" ]
    [ "${CYAN+set}" = "set" ]
    [ "${BOLD+set}" = "set" ]
    [ "${DIM+set}" = "set" ]
    [ "${NC+set}" = "set" ]
}

# --- Double-source guard ---

@test "colors: double-sourcing is guarded" {
    unset _FW_COLORS_LOADED
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    # First source sets guard
    [ -n "$_FW_COLORS_LOADED" ]
    # Second source should be a no-op
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    [ "$_FW_COLORS_LOADED" = "1" ]
}
