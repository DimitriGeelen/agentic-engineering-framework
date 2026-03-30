#!/usr/bin/env bats
# Unit tests for lib/init.sh
#
# Tests do_init argument parsing, help, guards, and generator functions

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export FW_VERSION="1.0.0"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/init.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "init: do_init --help shows usage" {
    run do_init --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw init"* ]]
    [[ "$output" == *"--provider"* ]]
    [[ "$output" == *"--force"* ]]
    [[ "$output" == *"--no-first-run"* ]]
}

@test "init: do_init --help shows provider options" {
    run do_init --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude"* ]]
    [[ "$output" == *"cursor"* ]]
    [[ "$output" == *"generic"* ]]
}

@test "init: do_init --help shows examples" {
    run do_init --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Examples"* ]]
}

@test "init: do_init rejects unknown option" {
    run do_init --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "init: do_init rejects nonexistent directory" {
    run do_init "/nonexistent/dir/xyz"
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "init: do_init rejects already initialized project" {
    local proj="$TEST_TEMP_DIR/init-test"
    mkdir -p "$proj"
    echo "framework_root: /opt" > "$proj/.framework.yaml"
    run do_init "$proj"
    [ "$status" -eq 1 ]
    [[ "$output" == *"already initialized"* ]]
}

@test "init: do_init --force bypasses already initialized guard" {
    local proj="$TEST_TEMP_DIR/init-force"
    mkdir -p "$proj"
    echo "framework_root: /opt" > "$proj/.framework.yaml"
    run do_init "$proj" --force
    # Should NOT say "already initialized" — gets past the guard
    [[ "$output" != *"already initialized"* ]]
}

@test "init: generate_claude_md function exists" {
    type generate_claude_md >/dev/null 2>&1
}

@test "init: generate_claude_code_config function exists" {
    type generate_claude_code_config >/dev/null 2>&1
}

@test "init: generate_cursorrules function exists" {
    type generate_cursorrules >/dev/null 2>&1
}
