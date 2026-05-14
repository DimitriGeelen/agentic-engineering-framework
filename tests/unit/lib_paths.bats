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

# T-1822: vendored .agentic-framework/ resolution.
# When FRAMEWORK_ROOT points at a vendored .agentic-framework/ with its own
# .git (post-`fw vendor` shape) AND parent has .framework.yaml, prefer the
# outer consumer as PROJECT_ROOT — otherwise cwd-inside-vendored-copy traps
# consumer agents (session-fatal; B-1, fw-upgrade-incident-2026-05-14).
@test "paths: vendored case — basename .agentic-framework + .framework.yaml parent → PROJECT_ROOT is parent" {
    mkdir -p "$TEST_TEMP_DIR/consumer/.agentic-framework"
    touch "$TEST_TEMP_DIR/consumer/.framework.yaml"
    export FRAMEWORK_ROOT="$TEST_TEMP_DIR/consumer/.agentic-framework"
    unset PROJECT_ROOT TASKS_DIR CONTEXT_DIR
    unset _FW_PATHS_LOADED _FW_COMPAT_LOADED _FW_TASKS_LOADED _FW_YAML_LOADED _FW_ERRORS_LOADED
    source "$ORIG_FRAMEWORK_ROOT/lib/paths.sh"
    [ "$PROJECT_ROOT" = "$TEST_TEMP_DIR/consumer" ]
}

@test "paths: standalone — FRAMEWORK_ROOT not named .agentic-framework keeps git-toplevel resolution" {
    export FRAMEWORK_ROOT="$ORIG_FRAMEWORK_ROOT"
    unset PROJECT_ROOT TASKS_DIR CONTEXT_DIR
    unset _FW_PATHS_LOADED _FW_COMPAT_LOADED _FW_TASKS_LOADED _FW_YAML_LOADED _FW_ERRORS_LOADED
    source "$ORIG_FRAMEWORK_ROOT/lib/paths.sh"
    expected="$(git -C "$ORIG_FRAMEWORK_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$ORIG_FRAMEWORK_ROOT")"
    [ "$PROJECT_ROOT" = "$expected" ]
}

@test "paths: vendored basename without .framework.yaml parent does NOT collapse to parent" {
    # Defensive: basename matches but no .framework.yaml — vendored branch must not fire.
    mkdir -p "$TEST_TEMP_DIR/not-a-consumer/.agentic-framework"
    export FRAMEWORK_ROOT="$TEST_TEMP_DIR/not-a-consumer/.agentic-framework"
    unset PROJECT_ROOT TASKS_DIR CONTEXT_DIR
    unset _FW_PATHS_LOADED _FW_COMPAT_LOADED _FW_TASKS_LOADED _FW_YAML_LOADED _FW_ERRORS_LOADED
    source "$ORIG_FRAMEWORK_ROOT/lib/paths.sh"
    [ "$PROJECT_ROOT" != "$TEST_TEMP_DIR/not-a-consumer" ]
}
