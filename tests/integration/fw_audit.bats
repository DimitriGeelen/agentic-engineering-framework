#!/usr/bin/env bats
# Integration tests for fw audit subcommand
#
# Tests the CLI interface for compliance audit:
#   fw audit                — run all audit sections
#   fw audit --section X    — run specific section
#   fw audit --help         — show help

load ../test_helper

FW="$FRAMEWORK_ROOT/bin/fw"

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT
    mkdir -p "$PROJECT_ROOT/.tasks/active" "$PROJECT_ROOT/.tasks/completed"
    mkdir -p "$PROJECT_ROOT/.context/working" "$PROJECT_ROOT/.context/project"
    mkdir -p "$PROJECT_ROOT/.context/audits" "$PROJECT_ROOT/.context/episodic"
    mkdir -p "$PROJECT_ROOT/.context/handovers"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJECT_ROOT/.framework.yaml"
    # Initialize git repo for audit traceability checks
    git -C "$PROJECT_ROOT" init -q
    git -C "$PROJECT_ROOT" config user.email "test@test.com"
    git -C "$PROJECT_ROOT" config user.name "Test"
    echo "init" > "$PROJECT_ROOT/init.txt"
    git -C "$PROJECT_ROOT" add -A
    git -C "$PROJECT_ROOT" commit -q -m "Initial commit"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- Help ---

@test "fw audit --help: shows usage" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' audit --help 2>&1"
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"section"* ]]
}

# --- Run ---

@test "fw audit --section structure: runs structural check" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' audit --section structure 2>&1"
    # Exit 0 (all pass) or 1 (warnings) are both acceptable
    [ "$status" -le 1 ]
    [[ "$output" == *"PASS"* ]] || [[ "$output" == *"WARN"* ]] || [[ "$output" == *"structure"* ]]
}

@test "fw audit: produces YAML output file" {
    # Audit may exit 1 (warnings) — that's OK, we just need the output file
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' audit --section structure --output '$PROJECT_ROOT/.context/audits' 2>&1"
    [ "$status" -le 1 ]
    # Should produce a dated YAML audit report
    local count
    count=$(ls "$PROJECT_ROOT/.context/audits/"*.yaml 2>/dev/null | wc -l)
    [ "$count" -ge 1 ]
}
