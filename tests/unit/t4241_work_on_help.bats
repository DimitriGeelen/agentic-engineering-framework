#!/usr/bin/env bats
# T-4241 — `fw work-on --help` fell through to the create path as a task named
# "--help": off-tty it failed with "Missing required flag(s): --type" (exit 1),
# on a tty it could create a task literally called "--help". The help flags must
# print usage plus the flag list, exit 0, and never reach create-task.sh.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export TASKS_DIR="$TEST_TEMP_DIR/.tasks"
    export CONTEXT_DIR="$TEST_TEMP_DIR/.context"
    export NO_COLOR=1
    unset CLAUDECODE
    unset AI_AGENT

    mkdir -p "$TASKS_DIR/active" "$TASKS_DIR/completed" "$TASKS_DIR/templates"
    mkdir -p "$CONTEXT_DIR/working"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    cp "$FRAMEWORK_ROOT/.tasks/templates/zzz-default.md" "$TASKS_DIR/templates/" 2>/dev/null || true
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

_assert_help() {
    run "$FRAMEWORK_ROOT/bin/fw" work-on "$1" </dev/null
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Missing required"* ]]
    for flag in --type --description --owner --horizon --tags --related \
                --recommendation --rationale --i-am-human --switch-focus; do
        [[ "$output" == *"$flag"* ]] || { echo "help lacks $flag"; return 1; }
    done
    [ -z "$(ls -A "$TASKS_DIR/active")" ]
    [ ! -e "$CONTEXT_DIR/working/focus.yaml" ]
}

@test "fw work-on --help prints usage and flags, exit 0, creates nothing" {
    _assert_help --help
}

@test "fw work-on -h prints usage and flags, exit 0, creates nothing" {
    _assert_help -h
}

@test "fw work-on with no args still prints usage and exits 1" {
    run "$FRAMEWORK_ROOT/bin/fw" work-on </dev/null
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]
}
