#!/usr/bin/env bats
# Unit tests for lib/paths.sh
#
# Tests path resolution: FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"

    # Save originals
    ORIG_FRAMEWORK_ROOT="$FRAMEWORK_ROOT"
    ORIG_PROJECT_ROOT="${PROJECT_ROOT:-}"

    # Reset guard to allow re-sourcing
    unset _FW_PATHS_LOADED _FW_COMPAT_LOADED _FW_TASKS_LOADED _FW_YAML_LOADED _FW_ERRORS_LOADED
}

teardown() {
    # Restore originals
    export FRAMEWORK_ROOT="$ORIG_FRAMEWORK_ROOT"
    [ -n "$ORIG_PROJECT_ROOT" ] && export PROJECT_ROOT="$ORIG_PROJECT_ROOT" || unset PROJECT_ROOT
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "paths: sets FRAMEWORK_ROOT" {
    unset FRAMEWORK_ROOT
    unset PROJECT_ROOT
    export FRAMEWORK_ROOT="$ORIG_FRAMEWORK_ROOT"
    unset _FW_PATHS_LOADED
    source "$ORIG_FRAMEWORK_ROOT/lib/paths.sh"
    [ -n "$FRAMEWORK_ROOT" ]
    [ -d "$FRAMEWORK_ROOT" ]
}

@test "paths: sets TASKS_DIR from PROJECT_ROOT" {
    export FRAMEWORK_ROOT="$ORIG_FRAMEWORK_ROOT"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    unset TASKS_DIR CONTEXT_DIR
    unset _FW_PATHS_LOADED _FW_COMPAT_LOADED _FW_TASKS_LOADED _FW_YAML_LOADED _FW_ERRORS_LOADED
    source "$ORIG_FRAMEWORK_ROOT/lib/paths.sh"
    [ "$TASKS_DIR" = "$TEST_TEMP_DIR/.tasks" ]
}

@test "paths: sets CONTEXT_DIR from PROJECT_ROOT" {
    export FRAMEWORK_ROOT="$ORIG_FRAMEWORK_ROOT"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    unset TASKS_DIR CONTEXT_DIR
    unset _FW_PATHS_LOADED _FW_COMPAT_LOADED _FW_TASKS_LOADED _FW_YAML_LOADED _FW_ERRORS_LOADED
    source "$ORIG_FRAMEWORK_ROOT/lib/paths.sh"
    [ "$CONTEXT_DIR" = "$TEST_TEMP_DIR/.context" ]
}

@test "paths: preserves existing TASKS_DIR if set" {
    export FRAMEWORK_ROOT="$ORIG_FRAMEWORK_ROOT"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export TASKS_DIR="/custom/tasks"
    unset _FW_PATHS_LOADED _FW_COMPAT_LOADED _FW_TASKS_LOADED _FW_YAML_LOADED _FW_ERRORS_LOADED
    source "$ORIG_FRAMEWORK_ROOT/lib/paths.sh"
    [ "$TASKS_DIR" = "/custom/tasks" ]
}

@test "paths: exports variables for subprocesses" {
    export FRAMEWORK_ROOT="$ORIG_FRAMEWORK_ROOT"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    unset TASKS_DIR CONTEXT_DIR
    unset _FW_PATHS_LOADED _FW_COMPAT_LOADED _FW_TASKS_LOADED _FW_YAML_LOADED _FW_ERRORS_LOADED
    source "$ORIG_FRAMEWORK_ROOT/lib/paths.sh"
    # Check that variables are exported (available in subshell)
    result=$(bash -c 'echo $FRAMEWORK_ROOT')
    [ -n "$result" ]
}
