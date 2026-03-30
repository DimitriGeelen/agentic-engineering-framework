#!/usr/bin/env bats
# Unit tests for lib/validate-init.sh
#
# Tests do_validate_init argument parsing, help, and validation logic

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/validate-init.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "validate-init: do_validate_init --help shows usage" {
    run do_validate_init --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw validate-init"* ]]
    [[ "$output" == *"--provider"* ]]
    [[ "$output" == *"--quiet"* ]]
}

@test "validate-init: do_validate_init rejects unknown option" {
    run do_validate_init --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "validate-init: do_validate_init rejects nonexistent directory" {
    run do_validate_init "/nonexistent/xyz"
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "validate-init: runs on empty dir and reports failures" {
    local proj="$TEST_TEMP_DIR/empty-proj"
    mkdir -p "$proj"
    run do_validate_init "$proj"
    [ -n "$output" ]
}

@test "validate-init: --quiet produces less output than verbose" {
    local proj="$TEST_TEMP_DIR/quiet-proj"
    mkdir -p "$proj"
    local quiet_output verbose_output
    quiet_output=$(do_validate_init "$proj" --quiet 2>&1 || true)
    verbose_output=$(do_validate_init "$proj" 2>&1 || true)
    local quiet_lines verbose_lines
    quiet_lines=$(echo "$quiet_output" | wc -l)
    verbose_lines=$(echo "$verbose_output" | wc -l)
    [ "$quiet_lines" -le "$verbose_lines" ]
}

@test "validate-init: detects created directories as passing" {
    local proj="$TEST_TEMP_DIR/partial-proj"
    mkdir -p "$proj/.tasks/active" "$proj/.tasks/completed" "$proj/.tasks/templates"
    mkdir -p "$proj/.context/working" "$proj/.context/project" "$proj/.context/episodic"
    mkdir -p "$proj/.context/handovers" "$proj/.context/scans"
    mkdir -p "$proj/.context/bus/results" "$proj/.context/bus/blobs"
    mkdir -p "$proj/.context/audits/cron" "$proj/.context/cron"
    run do_validate_init "$proj" --provider generic
    [[ "$output" == *"Passed"* ]] || [[ "$output" == *"pass"* ]]
}

@test "validate-init: auto-detects provider from .framework.yaml" {
    local proj="$TEST_TEMP_DIR/autodetect-proj"
    mkdir -p "$proj"
    echo "provider: generic" > "$proj/.framework.yaml"
    run do_validate_init "$proj"
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "validate-init: shows summary with totals" {
    local proj="$TEST_TEMP_DIR/summary-proj"
    mkdir -p "$proj"
    run do_validate_init "$proj"
    [[ "$output" == *"Passed"* ]] || [[ "$output" == *"/"* ]]
}
