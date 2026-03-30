#!/usr/bin/env bats
# Unit tests for lib/preflight.sh
#
# Tests detect_pkg_manager(), individual check functions, and do_preflight --quiet

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    # Source preflight (it defines its own color fallbacks)
    source "$FRAMEWORK_ROOT/lib/preflight.sh" --quiet 2>/dev/null
    # Reset arrays that were populated during sourcing
    REQUIRED_MISSING=()
    RECOMMENDED_MISSING=()
    REQUIRED_INSTALL_CMDS=()
    RECOMMENDED_INSTALL_CMDS=()
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "preflight: detect_pkg_manager returns a known value" {
    local result
    result=$(detect_pkg_manager)
    # Should return apt, brew, dnf, pacman, or unknown
    [[ "$result" =~ ^(apt|brew|dnf|pacman|unknown)$ ]]
}

@test "preflight: check_bash passes on current system" {
    run check_bash
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]] || [[ "$output" == *"bash"* ]]
}

@test "preflight: check_git passes when git is installed" {
    if ! command -v git >/dev/null 2>&1; then
        skip "git not installed"
    fi
    run check_git
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "preflight: check_python3 passes when python3 is installed" {
    if ! command -v python3 >/dev/null 2>&1; then
        skip "python3 not installed"
    fi
    run check_python3
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "preflight: check_pyyaml passes when PyYAML is installed" {
    if ! python3 -c "import yaml" 2>/dev/null; then
        skip "PyYAML not installed"
    fi
    run check_pyyaml
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "preflight: check_write_perms passes for writable directory" {
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    run check_write_perms
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "preflight: check_write_perms fails for non-writable directory" {
    # Root can write to any directory, so skip this test when running as root
    if [ "$(id -u)" -eq 0 ]; then
        skip "running as root — write perms always pass"
    fi
    local readonly_dir="$TEST_TEMP_DIR/readonly"
    mkdir -p "$readonly_dir"
    chmod 444 "$readonly_dir"
    export PROJECT_ROOT="$readonly_dir"
    run check_write_perms
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
    # Restore permissions for cleanup
    chmod 755 "$readonly_dir"
}

@test "preflight: check_shellcheck returns 0 or 1" {
    run check_shellcheck
    # Should pass if shellcheck installed, fail with WARN if not
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "preflight: check_git_identity returns 0 or 1" {
    run check_git_identity
    # Will pass if git identity is configured, warn if not
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "preflight: do_preflight --quiet returns 0 on healthy system" {
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    # Reset arrays
    REQUIRED_MISSING=()
    RECOMMENDED_MISSING=()
    run do_preflight --quiet
    [ "$status" -eq 0 ]
}

@test "preflight: do_preflight --check-only shows dependency check output" {
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    # Reset QUIET which was set during sourcing with --quiet
    QUIET=false
    CHECK_ONLY=false
    run do_preflight --check-only
    [ "$status" -eq 0 ]
    # Output should contain the dependency check header or check results
    [[ "$output" == *"preflight"* ]] || [[ "$output" == *"OK"* ]] || [[ "$output" == *"passed"* ]]
}
