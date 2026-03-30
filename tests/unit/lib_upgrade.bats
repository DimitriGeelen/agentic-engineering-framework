#!/usr/bin/env bats
# Unit tests for lib/upgrade.sh
#
# Tests do_upgrade argument parsing, help, and guards

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export FW_VERSION="1.5.0"
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/upgrade.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "upgrade: do_upgrade --help shows usage" {
    run do_upgrade --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw upgrade"* ]]
    [[ "$output" == *"--dry-run"* ]]
    [[ "$output" == *"--force"* ]]
}

@test "upgrade: do_upgrade --help shows what gets upgraded" {
    run do_upgrade --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"What gets upgraded"* ]]
    [[ "$output" == *"CLAUDE.md"* ]]
    [[ "$output" == *"Task templates"* ]]
    [[ "$output" == *"Git hooks"* ]]
}

@test "upgrade: do_upgrade rejects unknown option" {
    run do_upgrade --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "upgrade: do_upgrade rejects nonexistent directory" {
    run do_upgrade "/nonexistent/dir/xyz"
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "upgrade: do_upgrade rejects project without .framework.yaml" {
    local proj="$TEST_TEMP_DIR/no-fw"
    mkdir -p "$proj"
    run do_upgrade "$proj"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Not a framework project"* ]]
}

@test "upgrade: do_upgrade rejects upgrading framework itself" {
    # Create .framework.yaml so it passes the first guard and hits the self-check
    local had_fw=false
    [ -f "$FRAMEWORK_ROOT/.framework.yaml" ] && had_fw=true
    [ "$had_fw" = false ] && echo "framework_root: $FRAMEWORK_ROOT" > "$FRAMEWORK_ROOT/.framework.yaml"
    run do_upgrade "$FRAMEWORK_ROOT"
    [ "$had_fw" = false ] && rm -f "$FRAMEWORK_ROOT/.framework.yaml"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Cannot upgrade the framework project itself"* ]]
}

@test "upgrade: do_upgrade --dry-run shows dry run mode" {
    local proj="$TEST_TEMP_DIR/dry-proj"
    mkdir -p "$proj"
    echo "framework_root: $FRAMEWORK_ROOT" > "$proj/.framework.yaml"
    run do_upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
}

@test "upgrade: do_upgrade shows version info" {
    local proj="$TEST_TEMP_DIR/ver-proj"
    mkdir -p "$proj"
    echo -e "framework_root: $FRAMEWORK_ROOT\nversion: 1.4.0" > "$proj/.framework.yaml"
    run do_upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.4.0"* ]]
    [[ "$output" == *"1.5.0"* ]]
}

@test "upgrade: do_upgrade shows current version match" {
    local proj="$TEST_TEMP_DIR/cur-proj"
    mkdir -p "$proj"
    echo -e "framework_root: $FRAMEWORK_ROOT\nversion: 1.5.0" > "$proj/.framework.yaml"
    run do_upgrade "$proj" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"current"* ]]
}
