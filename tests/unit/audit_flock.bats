#!/usr/bin/env bats
# Unit tests for agents/audit/audit.sh flock guard (T-1464)
# Verifies foreground audits also flock-protect (lifted T-1162's QUIET-only guard).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    TMP_PROJECT="$(mktemp -d)"
    mkdir -p "$TMP_PROJECT/.context/locks"
    mkdir -p "$TMP_PROJECT/.context/audits"
    mkdir -p "$TMP_PROJECT/.tasks/active"
    mkdir -p "$TMP_PROJECT/.tasks/completed"
    mkdir -p "$TMP_PROJECT/.tasks/templates"
    touch "$TMP_PROJECT/.tasks/templates/zzz-default.md"
    export PROJECT_ROOT="$TMP_PROJECT"
    export CONTEXT_DIR="$TMP_PROJECT/.context"
    export TASKS_DIR="$TMP_PROJECT/.tasks"
}

teardown() {
    rm -rf "$TMP_PROJECT"
    unset PROJECT_ROOT CONTEXT_DIR TASKS_DIR
}

# --- Source-level checks ---

@test "audit.sh: flock guard is no longer wrapped in QUIET-only conditional" {
    # The guard region between AUDIT_LOCK_DIR= and the closing 'fi'/'else' should not
    # itself be inside an `if [ "$QUIET" = true ]; then` block.
    run grep -B1 'AUDIT_LOCK_DIR="\${CONTEXT_DIR}/locks"' "$AUDIT"
    [ "$status" -eq 0 ]
    # The line immediately above the guard should NOT be the QUIET test wrapper
    [[ "$output" != *'if [ "$QUIET" = true ]; then'* ]] || \
        [[ "$output" == *"--"* ]]  # heredoc separator if grep -B1 nothing-found
}

@test "audit.sh: foreground collision message present in source" {
    run grep -q "Another audit is already running" "$AUDIT"
    [ "$status" -eq 0 ]
}

@test "audit.sh: passes shell syntax check after edit" {
    run bash -n "$AUDIT"
    [ "$status" -eq 0 ]
}

# --- Behavioural collision test ---

@test "audit.sh: foreground collision exits 0 with stderr message when lock held" {
    skip_if_no_flock
    LOCK_FILE="$TMP_PROJECT/.context/locks/audit.lock"
    # Hold the lock from another process for the duration of the run
    (
        flock -x 200
        sleep 5
    ) 200>"$LOCK_FILE" &
    HOLDER_PID=$!
    sleep 0.5  # ensure holder has the lock

    run "$AUDIT" --section structure
    # Expect immediate exit 0 (silent on stdout, stderr message)
    [ "$status" -eq 0 ]
    [[ "$output" == *"Another audit is already running"* ]]

    kill "$HOLDER_PID" 2>/dev/null || true
    wait "$HOLDER_PID" 2>/dev/null || true
}

@test "audit.sh: cron-mode (--quiet) collision exits 0 silently when lock held" {
    skip_if_no_flock
    LOCK_FILE="$TMP_PROJECT/.context/locks/audit.lock"
    (
        flock -x 200
        sleep 5
    ) 200>"$LOCK_FILE" &
    HOLDER_PID=$!
    sleep 0.5

    run "$AUDIT" --quiet --section structure
    [ "$status" -eq 0 ]
    # No "Another audit" message in quiet mode
    [[ "$output" != *"Another audit is already running"* ]]

    kill "$HOLDER_PID" 2>/dev/null || true
    wait "$HOLDER_PID" 2>/dev/null || true
}

skip_if_no_flock() {
    if ! command -v flock >/dev/null 2>&1; then
        skip "flock not available"
    fi
}
