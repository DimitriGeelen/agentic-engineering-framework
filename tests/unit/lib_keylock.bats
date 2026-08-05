#!/usr/bin/env bats
# Unit tests for lib/keylock.sh
#
# Tests keylock_acquire, keylock_release, _keylock_path, _keylock_clean_stale

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    export FRAMEWORK_ROOT

    # Reset guard to allow re-sourcing
    unset _KEYLOCK_LOADED
    source "$FRAMEWORK_ROOT/lib/keylock.sh"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# --- _keylock_path ---

@test "keylock: path sanitizes key name" {
    result=$(_keylock_path "T-042")
    [[ "$result" == *"T-042.lock" ]]
}

@test "keylock: path sanitizes special characters" {
    result=$(_keylock_path "key/with spaces")
    [[ "$result" == *".lock" ]]
    # Should not contain slashes or spaces in filename
    local basename
    basename=$(basename "$result")
    [[ "$basename" != *"/"* ]]
    [[ "$basename" != *" "* ]]
}

# --- keylock_acquire / keylock_release ---

@test "keylock: acquire creates lock file" {
    keylock_acquire "testkey"
    [ -f "$PROJECT_ROOT/.context/locks/testkey.lock" ]
    keylock_release "testkey"
}

@test "keylock: release succeeds after acquire" {
    keylock_acquire "releasetest"
    run keylock_release "releasetest"
    [ "$status" -eq 0 ]
}

@test "keylock: acquire requires key argument" {
    run keylock_acquire ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"key required"* ]]
}

@test "keylock: release requires key argument" {
    run keylock_release ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"key required"* ]]
}

@test "keylock: release without acquire succeeds silently" {
    run keylock_release "never-acquired"
    [ "$status" -eq 0 ]
}

# --- _keylock_clean_stale ---

@test "keylock: cleans stale locks" {
    mkdir -p "$PROJECT_ROOT/.context/locks"
    local lock_file="$PROJECT_ROOT/.context/locks/stale-test.lock"
    touch "$lock_file"
    # Set modification time to 600 seconds ago (past the 300s default timeout)
    touch -d "10 minutes ago" "$lock_file"
    run _keylock_clean_stale "$lock_file"
    [ "$status" -eq 0 ]
    [ ! -f "$lock_file" ]
}

@test "keylock: does not clean fresh locks" {
    mkdir -p "$PROJECT_ROOT/.context/locks"
    local lock_file="$PROJECT_ROOT/.context/locks/fresh-test.lock"
    touch "$lock_file"
    run _keylock_clean_stale "$lock_file"
    [ "$status" -eq 1 ]
    [ -f "$lock_file" ]
}
