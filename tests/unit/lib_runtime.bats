#!/usr/bin/env bats
# Unit tests for lib/runtime.sh
#
# Tests fw_run_ts() — TypeScript/Python runtime fallback

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    source "$FRAMEWORK_ROOT/lib/runtime.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "runtime: fw_run_ts errors when script not found" {
    run fw_run_ts "nonexistent-script" arg1 arg2
    [ "$status" -eq 1 ]
    [[ "$output" == *"No runtime available"* ]]
}

@test "runtime: fw_run_ts error message includes script name" {
    run fw_run_ts "my-missing-tool" arg1
    [[ "$output" == *"my-missing-tool"* ]]
}

@test "runtime: fw_run_ts runs JS if available" {
    # Create a mock JS script
    mkdir -p "$FRAMEWORK_ROOT/lib/ts/dist"
    local mock_js="$FRAMEWORK_ROOT/lib/ts/dist/test-mock.js"
    echo 'console.log("js-output:" + process.argv.slice(2).join(","))' > "$mock_js"

    run fw_run_ts "test-mock" hello world
    rm -f "$mock_js"

    [ "$status" -eq 0 ]
    [[ "$output" == *"js-output:hello,world"* ]]
}

@test "runtime: fw_run_ts falls back to Python" {
    # Ensure no JS exists for this script
    rm -f "$FRAMEWORK_ROOT/lib/ts/dist/test-py-fallback.js"

    # Create a mock Python script
    mkdir -p "$FRAMEWORK_ROOT/lib/py"
    local mock_py="$FRAMEWORK_ROOT/lib/py/test-py-fallback.py"
    echo 'import sys; print("py-output:" + ",".join(sys.argv[1:]))' > "$mock_py"

    run fw_run_ts "test-py-fallback" a b c
    rm -f "$mock_py"

    [ "$status" -eq 0 ]
    [[ "$output" == *"py-output:a,b,c"* ]]
}

@test "runtime: fw_run_ts error shows both runtime options" {
    run fw_run_ts "missing" arg
    [[ "$output" == *"node"* ]]
    [[ "$output" == *"python3"* ]]
}
