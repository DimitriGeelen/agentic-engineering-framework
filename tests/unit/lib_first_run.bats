#!/usr/bin/env bats
# Unit tests for lib/first-run.sh
#
# Tests do_first_run output and structure

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    # Stub fw command so do_first_run doesn't call real fw
    export PATH="$TEST_TEMP_DIR/bin:$PATH"
    mkdir -p "$TEST_TEMP_DIR/bin"
    cat > "$TEST_TEMP_DIR/bin/fw" <<'STUB'
#!/bin/bash
echo "fw stub: $*"
STUB
    chmod +x "$TEST_TEMP_DIR/bin/fw"
    source "$FRAMEWORK_ROOT/lib/first-run.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "first-run: do_first_run shows walkthrough header" {
    run do_first_run "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"First Run Walkthrough"* ]]
}

@test "first-run: do_first_run shows 3 steps" {
    run do_first_run "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Step 1/3"* ]]
    [[ "$output" == *"Step 2/3"* ]]
    [[ "$output" == *"Step 3/3"* ]]
}

@test "first-run: do_first_run shows useful commands" {
    run do_first_run "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw help"* ]]
    [[ "$output" == *"fw audit"* ]]
    [[ "$output" == *"fw doctor"* ]]
}

@test "first-run: do_first_run shows work-on command" {
    run do_first_run "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw work-on"* ]]
}

@test "first-run: do_first_run shows handover command" {
    run do_first_run "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw handover"* ]]
}

@test "first-run: do_first_run shows Setup complete" {
    run do_first_run "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Setup complete"* ]]
}

@test "first-run: do_first_run calls fw doctor" {
    run do_first_run "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw doctor"* ]]
}

@test "first-run: do_first_run calls fw context init" {
    run do_first_run "$TEST_TEMP_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw context init"* ]]
}

@test "first-run: do_first_run defaults to current dir" {
    run do_first_run
    [ "$status" -eq 0 ]
    [[ "$output" == *"First Run Walkthrough"* ]]
}
