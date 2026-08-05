#!/usr/bin/env bats
# Integration tests for fw consolidate subcommand

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
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "fw consolidate: no subcommand shows help" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' consolidate"
    [[ "$output" == *"consolidate"* ]] || [[ "$output" == *"scan"* ]] || [[ "$output" == *"apply"* ]]
}

@test "fw consolidate scan: runs on empty project" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' consolidate scan"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Consolidation Report"* ]] || [[ "$output" == *"Report written"* ]]
}

@test "fw consolidate scan: creates report file" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' consolidate scan" > /dev/null 2>&1
    [ -f "$PROJECT_ROOT/.context/working/consolidation-report.yaml" ]
}

@test "fw consolidate report: shows cached report" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' consolidate scan" > /dev/null 2>&1
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' consolidate report"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Consolidation Report"* ]] || [[ "$output" == *"Learnings"* ]]
}
