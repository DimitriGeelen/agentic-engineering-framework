#!/usr/bin/env bats
# T-1366: keylock_acquire optional timeout argument.
#
# keylock_acquire <key>           — block forever (default; backward compatible)
# keylock_acquire <key> <seconds> — block up to N seconds, return 1 on timeout

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.context/locks"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "keylock_acquire: no timeout arg blocks (backward compatible)" {
    # Acquire, release in same shell — should succeed without hanging
    bash -c "
        set -e
        source '$FRAMEWORK_ROOT/lib/keylock.sh'
        keylock_acquire 'tkey1'
        keylock_release 'tkey1'
    "
    [ "$?" -eq 0 ]
}

@test "keylock_acquire: timeout fires when lock held by another process" {
    # Background holder
    local holder_log="$TEST_TEMP_DIR/holder.log"
    bash -c "
        source '$FRAMEWORK_ROOT/lib/keylock.sh'
        keylock_acquire 'contended'
        echo 'acquired' > '$holder_log'
        sleep 5
        keylock_release 'contended'
    " &
    local holder_pid=$!

    # Wait for holder to grab the lock
    local waited=0
    while [ ! -f "$holder_log" ] && [ "$waited" -lt 20 ]; do
        sleep 0.1
        waited=$((waited + 1))
    done
    [ -f "$holder_log" ]

    # Now try to acquire with 1s timeout — should fail
    local start_time end_time elapsed
    start_time=$(date +%s)
    run bash -c "
        source '$FRAMEWORK_ROOT/lib/keylock.sh'
        keylock_acquire 'contended' 1
    "
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))

    # Clean up holder
    kill "$holder_pid" 2>/dev/null || true
    wait "$holder_pid" 2>/dev/null || true

    [ "$status" -eq 1 ]
    # Should have taken ~1s, not 5s
    [ "$elapsed" -lt 3 ]
}

@test "keylock_acquire: timeout 0 behaves as non-blocking (immediate fail if locked)" {
    # Background holder
    bash -c "
        source '$FRAMEWORK_ROOT/lib/keylock.sh'
        keylock_acquire 'nbkey'
        sleep 3
        keylock_release 'nbkey'
    " &
    local holder_pid=$!

    # Give holder time to acquire
    sleep 0.3

    # Non-blocking attempt with timeout=0
    run bash -c "
        source '$FRAMEWORK_ROOT/lib/keylock.sh'
        keylock_acquire 'nbkey' 0
    "
    [ "$status" -eq 1 ]

    # Cleanup
    kill "$holder_pid" 2>/dev/null || true
    wait "$holder_pid" 2>/dev/null || true
}

@test "keylock_acquire: with timeout, succeeds when lock is free" {
    bash -c "
        set -e
        source '$FRAMEWORK_ROOT/lib/keylock.sh'
        keylock_acquire 'freekey' 5
        keylock_release 'freekey'
    "
    [ "$?" -eq 0 ]
}
