#!/usr/bin/env bats
# Unit tests for lib/bus.sh
#
# Tests do_bus_post, do_bus_read, do_bus_manifest, do_bus_clear

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FW_LIB_DIR="$FRAMEWORK_ROOT/lib"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/bus.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "bus: BUS_SIZE_GATE defaults to 2048" {
    [ "$BUS_SIZE_GATE" -eq 2048 ]
}

@test "bus: do_bus_help shows usage" {
    run do_bus_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw bus"* ]]
    [[ "$output" == *"post"* ]]
    [[ "$output" == *"read"* ]]
    [[ "$output" == *"manifest"* ]]
    [[ "$output" == *"clear"* ]]
}

@test "bus: do_bus routes help" {
    run do_bus --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw bus"* ]]
}

@test "bus: do_bus routes empty to help" {
    run do_bus
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw bus"* ]]
}

@test "bus: do_bus rejects unknown subcommand" {
    run do_bus bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown bus command"* ]]
}

@test "bus: do_bus_post requires --task" {
    run do_bus_post --agent explore --summary "test"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--task is required"* ]]
}

@test "bus: do_bus_post requires --agent" {
    run do_bus_post --task T-999 --summary "test"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--agent is required"* ]]
}

@test "bus: do_bus_post requires --summary" {
    run do_bus_post --task T-999 --agent explore
    [ "$status" -eq 1 ]
    [[ "$output" == *"--summary is required"* ]]
}

@test "bus: do_bus_post creates result envelope" {
    run do_bus_post --task T-999 --agent explore --summary "Found 3 issues"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Posted"* ]]
    [[ "$output" == *"R-001"* ]]
    # Verify file was created
    [ -f "$TEST_TEMP_DIR/.context/bus/results/T-999/R-001.yaml" ]
}

@test "bus: do_bus_post stores inline payload" {
    run do_bus_post --task T-999 --agent explore --summary "Test" --result "inline data here"
    [ "$status" -eq 0 ]
    [[ "$output" == *"inline"* ]]
    # Verify YAML contains the payload
    grep -q "inline data here" "$TEST_TEMP_DIR/.context/bus/results/T-999/R-001.yaml"
}

@test "bus: do_bus_post auto-increments result IDs" {
    do_bus_post --task T-999 --agent explore --summary "First"
    do_bus_post --task T-999 --agent explore --summary "Second"
    run do_bus_post --task T-999 --agent explore --summary "Third"
    [ "$status" -eq 0 ]
    [[ "$output" == *"R-003"* ]]
    [ -f "$TEST_TEMP_DIR/.context/bus/results/T-999/R-001.yaml" ]
    [ -f "$TEST_TEMP_DIR/.context/bus/results/T-999/R-002.yaml" ]
    [ -f "$TEST_TEMP_DIR/.context/bus/results/T-999/R-003.yaml" ]
}

@test "bus: do_bus_post rejects missing blob file" {
    run do_bus_post --task T-999 --agent code --summary "Test" --blob "/nonexistent/file.txt"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Blob file not found"* ]]
}

@test "bus: do_bus_post handles blob reference" {
    local blob_file="$TEST_TEMP_DIR/large-output.txt"
    echo "some blob content" > "$blob_file"
    run do_bus_post --task T-999 --agent code --summary "Wrote report" --blob "$blob_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"blob"* ]]
}

@test "bus: do_bus_read requires task ID" {
    run do_bus_read
    [ "$status" -eq 1 ]
    [[ "$output" == *"Task ID required"* ]]
}

@test "bus: do_bus_read handles missing channel" {
    run do_bus_read T-000
    [ "$status" -eq 0 ]
    [[ "$output" == *"No results"* ]]
}

@test "bus: do_bus_read lists results" {
    do_bus_post --task T-999 --agent explore --summary "First result"
    do_bus_post --task T-999 --agent code --summary "Second result"
    run do_bus_read T-999
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 results"* ]]
}

@test "bus: do_bus_read specific result" {
    do_bus_post --task T-999 --agent explore --summary "Specific result" --result "detail"
    run do_bus_read T-999 R-001
    [ "$status" -eq 0 ]
    [[ "$output" == *"explore"* ]]
    [[ "$output" == *"Specific result"* ]]
}

@test "bus: do_bus_read nonexistent result" {
    mkdir -p "$TEST_TEMP_DIR/.context/bus/results/T-999"
    run do_bus_read T-999 R-999
    [ "$status" -eq 1 ]
    [[ "$output" == *"Result not found"* ]]
}

@test "bus: do_bus_manifest shows no channels" {
    run do_bus_manifest
    [ "$status" -eq 0 ]
    [[ "$output" == *"No bus channels"* ]]
}

@test "bus: do_bus_manifest shows channel summary" {
    do_bus_post --task T-999 --agent explore --summary "Test"
    run do_bus_manifest
    [ "$status" -eq 0 ]
    [[ "$output" == *"T-999"* ]]
}

@test "bus: do_bus_manifest with task ID shows results" {
    do_bus_post --task T-999 --agent explore --summary "First"
    do_bus_post --task T-999 --agent code --summary "Second"
    run do_bus_manifest T-999
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 results"* ]]
    [[ "$output" == *"R-001"* ]]
    [[ "$output" == *"R-002"* ]]
}

@test "bus: do_bus_clear requires task ID" {
    run do_bus_clear
    [ "$status" -eq 1 ]
    [[ "$output" == *"Task ID required"* ]]
}

@test "bus: do_bus_clear removes channel" {
    do_bus_post --task T-999 --agent explore --summary "Will be cleared"
    [ -d "$TEST_TEMP_DIR/.context/bus/results/T-999" ]
    run do_bus_clear T-999
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cleared"* ]]
    [[ "$output" == *"1 results"* ]]
    [ ! -d "$TEST_TEMP_DIR/.context/bus/results/T-999" ]
}

@test "bus: do_bus_clear handles empty channel" {
    run do_bus_clear T-000
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 results"* ]]
}
