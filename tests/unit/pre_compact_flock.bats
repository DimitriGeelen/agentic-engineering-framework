#!/usr/bin/env bats
# T-1476 — pre-compact.sh acquires a flock to prevent dual handover commits
# when both user-level and project-level PreCompact hooks fire (OBS-023).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    export NO_COLOR=1
    export FRAMEWORK_ROOT
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# ---- Source-level invariants ----

@test "pre-compact.sh defines PRE_COMPACT_LOCK_FILE (T-1476)" {
    grep -q 'PRE_COMPACT_LOCK_FILE=' "$FRAMEWORK_ROOT/agents/context/pre-compact.sh"
}

@test "pre-compact.sh acquires flock on FD 201 (T-1476)" {
    grep -q 'exec 201>' "$FRAMEWORK_ROOT/agents/context/pre-compact.sh"
    grep -q 'flock -n 201' "$FRAMEWORK_ROOT/agents/context/pre-compact.sh"
}

@test "pre-compact.sh exits silently when lock cannot be acquired (T-1476)" {
    # Confirms: if flock -n fails, the script exits 0 without doing handover work.
    # Pattern: `if ! flock -n 201; then ... exit 0 ... fi`
    awk '/if ! flock -n 201/,/fi/' "$FRAMEWORK_ROOT/agents/context/pre-compact.sh" | grep -q 'exit 0'
}

@test "pre-compact.sh does NOT trap-rm the lockfile (T-1478 fix)" {
    # T-1476 originally added: trap "rm -f '$PRE_COMPACT_LOCK_FILE'" EXIT
    # T-1478 found that trap to be the cause of sequential bypass: A's trap
    # removed the lockfile on exit, so B opened a fresh inode and got a fresh
    # lock. The trap was removed; the lockfile is left in place (empty, harmless).
    ! grep -qE "^[[:space:]]*trap[[:space:]].*rm[[:space:]].*PRE_COMPACT_LOCK_FILE.*EXIT" "$FRAMEWORK_ROOT/agents/context/pre-compact.sh"
}

@test "pre-compact.sh degrades gracefully when flock is missing (T-1476)" {
    # Body wraps flock setup in `if command -v flock >/dev/null 2>&1`
    grep -q 'command -v flock' "$FRAMEWORK_ROOT/agents/context/pre-compact.sh"
}

# ---- Behavioural: real lock acquisition ----

@test "second flock -n on same FD fails (lock-acquisition smoke test)" {
    cd "$TEST_TEMP_DIR"
    touch lockfile
    # Hold the lock in a subshell.
    (
        exec 201>lockfile
        flock -n 201
        sleep 1
    ) &
    bg_pid=$!
    # Give the holder a moment to acquire.
    sleep 0.2
    # Second attempt must fail.
    exec 202>lockfile
    if flock -n 202; then
        kill "$bg_pid" 2>/dev/null
        wait "$bg_pid" 2>/dev/null
        false  # We expected the second flock to fail.
    fi
    # Cleanup the holder.
    wait "$bg_pid" 2>/dev/null
    true
}

# ---- Sanity ----

@test "pre-compact.sh parses (bash -n) (T-1476)" {
    bash -n "$FRAMEWORK_ROOT/agents/context/pre-compact.sh"
}
