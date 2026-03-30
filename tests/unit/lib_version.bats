#!/usr/bin/env bats
# Unit tests for lib/version.sh
#
# Tests _read_fw_version(), do_version_bump (dry-run), do_version_check

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$FRAMEWORK_ROOT"
    # Source dependencies
    export NO_COLOR=1
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/compat.sh"
    source "$FRAMEWORK_ROOT/lib/errors.sh"
    source "$FRAMEWORK_ROOT/lib/version.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "version: _read_fw_version returns FW_VERSION" {
    export FW_VERSION="1.2.3"
    local result
    result=$(_read_fw_version)
    [ "$result" = "1.2.3" ]
}

@test "version: _read_fw_version returns empty when unset" {
    unset FW_VERSION
    local result
    result=$(_read_fw_version)
    [ -z "$result" ]
}

@test "version: VERSION_STALENESS_THRESHOLD is defined" {
    [ -n "$VERSION_STALENESS_THRESHOLD" ]
    [ "$VERSION_STALENESS_THRESHOLD" -eq 50 ]
}

@test "version: do_version_bump requires component" {
    export FW_VERSION="1.0.0"
    run do_version_bump
    [ "$status" -eq 1 ]
    [[ "$output" == *"Version component required"* ]]
}

@test "version: do_version_bump rejects unknown options" {
    export FW_VERSION="1.0.0"
    run do_version_bump --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "version: do_version_bump --help exits 0" {
    run do_version_bump --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"fw version bump"* ]]
}

@test "version: do_version_bump dry-run patch" {
    export FW_VERSION="1.2.3"
    run do_version_bump patch --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.2.3"* ]]
    [[ "$output" == *"1.2.4"* ]]
}

@test "version: do_version_bump dry-run minor" {
    export FW_VERSION="1.2.3"
    run do_version_bump minor --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.3.0"* ]]
}

@test "version: do_version_bump dry-run major" {
    export FW_VERSION="1.2.3"
    run do_version_bump major --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"2.0.0"* ]]
}

@test "version: do_version_bump dry-run with --tag" {
    export FW_VERSION="1.0.0"
    run do_version_bump patch --dry-run --tag
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.0.1"* ]]
    [[ "$output" == *"tag"* ]]
}

@test "version: do_version_bump blocks in consumer project" {
    export FW_VERSION="1.0.0"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    run do_version_bump patch --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"only available in the framework repo"* ]]
}

@test "version: do_version_bump fails on empty FW_VERSION" {
    unset FW_VERSION
    export FW_VERSION=""
    run do_version_bump patch --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"Could not read FW_VERSION"* ]]
}

@test "version: do_version_bump fails on invalid semver" {
    export FW_VERSION="not-a-version"
    run do_version_bump patch --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"not valid semver"* ]]
}

@test "version: _version_bump_help shows usage" {
    run _version_bump_help
    [ "$status" -eq 0 ]
    [[ "$output" == *"major"* ]]
    [[ "$output" == *"minor"* ]]
    [[ "$output" == *"patch"* ]]
    [[ "$output" == *"--dry-run"* ]]
}

@test "version: do_version_sync --help exits 0" {
    run do_version_sync --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sync all VERSION files"* ]]
}

@test "version: do_version_sync blocks in consumer project" {
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    run do_version_sync
    [ "$status" -eq 1 ]
    [[ "$output" == *"only available in the framework repo"* ]]
}
