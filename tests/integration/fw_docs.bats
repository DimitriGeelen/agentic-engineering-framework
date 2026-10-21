#!/usr/bin/env bats
# Integration tests for fw docs subcommand

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    # T-4522: docgen writes under FRAMEWORK_ROOT by default — the tracked
    # docs/generated tree — so point it at the temp dir instead.
    export DOCGEN_OUTPUT_DIR="$TEST_TEMP_DIR/docs-out"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "fw docs: no args shows usage" {
    run timeout 60 bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' docs"
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"docs"* ]] || [[ "$output" == *"--all"* ]]
}

@test "fw docs --all: generates component docs" {
    # T-4522: bounded. Before the fix each card re-parsed 200 episodic files and
    # learnings.yaml (~40 min for 1602 cards); 124 here means that came back.
    run timeout 300 bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' docs --all"
    [ "$status" -ne 124 ] || { echo "fw docs --all exceeded 300 s (T-4522 regression)"; false; }
    [ "$status" -eq 0 ]
    [[ "$output" == *"component docs generated"* ]]
    local n
    n=$(ls "$DOCGEN_OUTPUT_DIR" | wc -l)
    [ "$n" -eq "$(ls "$FRAMEWORK_ROOT/.fabric/components"/*.yaml | wc -l)" ]
}
