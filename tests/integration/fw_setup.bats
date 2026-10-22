#!/usr/bin/env bats
# Integration tests for fw setup subcommand (deprecated, wraps fw init)
#
# T-4599: `fw setup` is `fw init` with a notice in front, so it takes the target
# the same way: an explicit [dir], defaulting to $PWD. It never reads
# PROJECT_ROOT — that names an EXISTING project, and init creates one. These
# tests used to export PROJECT_ROOT, pre-write .framework.yaml into it and pass
# no dir, so setup ran against the bats cwd (the framework repo) and answered
# "Project already initialized at <framework repo>". Pass the dir, like
# fw_init.bats does, and leave it uninitialised so there is something to set up.

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "fw setup: shows deprecation notice" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' setup '$PROJECT_ROOT' 2>&1"
    [[ "$output" == *"deprecated"* ]]
    [[ "$output" == *"fw init"* ]]
}

@test "fw setup: sets up the named directory, not the cwd" {
    run bash -c "cd '$FRAMEWORK_ROOT' && FRAMEWORK_ROOT='$FRAMEWORK_ROOT' '$FW' setup '$PROJECT_ROOT' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" != *"already initialized"* ]]
    [ -f "$PROJECT_ROOT/.framework.yaml" ]
    [ -d "$PROJECT_ROOT/.tasks/active" ]
    [ -d "$PROJECT_ROOT/.context/working" ]
}
