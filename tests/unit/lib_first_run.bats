#!/usr/bin/env bats
# Unit tests for lib/first-run.sh (fw first-run)
# Origin: T-945

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
FIRST_RUN="$FRAMEWORK_ROOT/lib/first-run.sh"

@test "first-run script is sourceable" {
    # first-run.sh supports sourcing (defines do_first_run function)
    run bash -c "source '$FIRST_RUN' && type do_first_run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"function"* ]]
}

@test "first-run defines do_first_run function" {
    run bash -c "source '$FIRST_RUN' && declare -F do_first_run"
    [ "$status" -eq 0 ]
}

@test "first-run shows walkthrough header" {
    export TEST_DIR="$(mktemp -d)"
    run bash -c "source '$FIRST_RUN' && do_first_run '$TEST_DIR'" || true
    [[ "$output" == *"First Run"* ]] || [[ "$output" == *"Walkthrough"* ]]
    rm -rf "$TEST_DIR"
}

@test "first-run mentions key commands" {
    export TEST_DIR="$(mktemp -d)"
    run bash -c "source '$FIRST_RUN' && do_first_run '$TEST_DIR'" || true
    [[ "$output" == *"fw"* ]]
    rm -rf "$TEST_DIR"
}
