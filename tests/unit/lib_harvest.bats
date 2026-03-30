#!/usr/bin/env bats
# Unit tests for lib/harvest.sh
#
# Tests do_harvest argument parsing, help, guards, and sub-functions

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/harvest.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "harvest: do_harvest --help shows usage" {
    run do_harvest --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw harvest"* ]]
    [[ "$output" == *"--dry-run"* ]]
    [[ "$output" == *"--verbose"* ]]
}

@test "harvest: do_harvest --help shows graduation pipeline" {
    run do_harvest --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Graduation pipeline"* ]]
    [[ "$output" == *"local"* ]]
    [[ "$output" == *"candidate"* ]]
    [[ "$output" == *"practice"* ]]
}

@test "harvest: do_harvest rejects unknown option" {
    run do_harvest --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "harvest: do_harvest rejects harvesting from framework itself" {
    run do_harvest "$FRAMEWORK_ROOT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Cannot harvest from the framework itself"* ]]
}

@test "harvest: do_harvest rejects nonexistent directory" {
    run do_harvest "/nonexistent/dir/xyz"
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "harvest: do_harvest rejects project without context" {
    local proj="$TEST_TEMP_DIR/empty-project"
    mkdir -p "$proj"
    run do_harvest "$proj"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No .context/project/"* ]]
}

@test "harvest: harvest_patterns skips missing file" {
    run harvest_patterns "/nonexistent/patterns.yaml" "$TEST_TEMP_DIR/fw-patterns.yaml" "test-proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
}

@test "harvest: harvest_patterns skips empty patterns" {
    local pfile="$TEST_TEMP_DIR/patterns.yaml"
    echo "patterns: []" > "$pfile"
    run harvest_patterns "$pfile" "$TEST_TEMP_DIR/fw-patterns.yaml" "test-proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
}

@test "harvest: harvest_learnings skips missing file" {
    run harvest_learnings "/nonexistent/learnings.yaml" "$TEST_TEMP_DIR/fw-learnings.yaml" "test-proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
}

@test "harvest: harvest_decisions skips missing file" {
    run harvest_decisions "/nonexistent/decisions.yaml" "$TEST_TEMP_DIR/fw-decisions.yaml" "test-proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
}

@test "harvest: harvest_practices skips missing file" {
    run harvest_practices "/nonexistent/practices.yaml" "$TEST_TEMP_DIR/fw-practices.yaml" "test-proj"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKIP"* ]]
}
