#!/usr/bin/env bats
# Integration tests for fw build subcommand
#
# Tests TypeScript compilation stale guard, verbose output, and empty source handling.

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

@test "fw build: silent exit when no ts source directory" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' build"
    [ "$status" -eq 0 ]
}

@test "fw build: verbose reports up-to-date" {
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$PROJECT_ROOT' '$FW' build --verbose"
    [ "$status" -eq 0 ]
    [[ "$output" == *"up to date"* ]] || [[ "$output" == "" ]]
}

@test "fw build: succeeds with real framework sources" {
    # Build the actual framework TS sources
    run bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$FRAMEWORK_ROOT' '$FW' build"
    [ "$status" -eq 0 ]
}

@test "fw build: dist directory exists after build" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$FRAMEWORK_ROOT' '$FW' build" >/dev/null 2>&1
    [ -d "$FRAMEWORK_ROOT/lib/ts/dist" ]
}

@test "fw build: compiled JS files exist" {
    bash -c "FRAMEWORK_ROOT='$FRAMEWORK_ROOT' PROJECT_ROOT='$FRAMEWORK_ROOT' '$FW' build" >/dev/null 2>&1
    local src_count
    src_count=$(ls "$FRAMEWORK_ROOT/lib/ts/src/"*.ts 2>/dev/null | wc -l)
    if [ "$src_count" -gt 0 ]; then
        local dist_count
        dist_count=$(ls "$FRAMEWORK_ROOT/lib/ts/dist/"*.js 2>/dev/null | wc -l)
        [ "$dist_count" -ge "$src_count" ]
    fi
}
