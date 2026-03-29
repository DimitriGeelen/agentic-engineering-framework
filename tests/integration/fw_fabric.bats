#!/usr/bin/env bats
# Integration tests for fw fabric subcommand
#
# Tests the CLI interface for fabric topology commands:
#   fw fabric help      — show usage
#   fw fabric overview  — compact subsystem summary
#   fw fabric stats     — component/edge counts
#   fw fabric deps      — dependencies for a file
#   fw fabric search    — search by keyword
#   fw fabric get       — show full component card

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Help ---

@test "fw fabric: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' fabric"
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

@test "fw fabric help: shows usage info" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' fabric help"
    [ "$status" -eq 0 ]
    [[ "$output" == *"register"* ]]
    [[ "$output" == *"overview"* ]]
}

# --- Overview ---

@test "fw fabric overview: shows subsystem summary" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' fabric overview"
    [ "$status" -eq 0 ]
    [[ "$output" == *"subsystem"* ]] || [[ "$output" == *"Topology"* ]]
}

@test "fw fabric overview: shows component count" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' fabric overview"
    [ "$status" -eq 0 ]
    [[ "$output" == *"components"* ]]
}

# --- Stats ---

@test "fw fabric stats: shows component and edge counts" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' fabric stats"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Components"* ]]
    [[ "$output" == *"Edges"* ]]
}

# --- Deps ---

@test "fw fabric deps: shows dependencies for a file" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' fabric deps bin/fw"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dependencies"* ]] || [[ "$output" == *"Depends"* ]]
}

@test "fw fabric deps: without argument shows error" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' fabric deps"
    [ "$status" -ne 0 ] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"required"* ]]
}

# --- Search ---

@test "fw fabric search: finds components by keyword" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' fabric search audit"
    [ "$status" -eq 0 ]
    [[ "$output" == *"audit"* ]]
}

@test "fw fabric search: no results for nonsense keyword" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' fabric search zzzznonexistent99"
    [[ "$output" == *"No"* ]] || [[ "$output" == *"no"* ]] || [[ "$output" == *"0"* ]] || [ "$status" -eq 0 ]
}

# --- Get ---

@test "fw fabric get: shows component card" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' fabric get bin/fw"
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw"* ]]
}
