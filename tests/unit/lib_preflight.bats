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

@test "preflight: check_write_perms fails for an unwritable target" {
    # T-3217: this used to deny with `chmod 444` and then skip when running as
    # root — and the suite runs as root here and in CI, so the FAIL branch was
    # measured nowhere while the test reported ok. Same shape as T-3213's
    # `chmod 500` skip.
    #
    # `[ -w ]` is false for root on a path that does not exist, so a missing
    # directory denies every uid. It is a different denial from a permission
    # bit — stated rather than glossed — but it is the branch that matters:
    # check_write_perms takes it, sets REQUIRED_MISSING, and returns 1.
    export PROJECT_ROOT="$TEST_TEMP_DIR/does-not-exist"
    [ ! -e "$PROJECT_ROOT" ]
    run check_write_perms
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL"* ]]
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
