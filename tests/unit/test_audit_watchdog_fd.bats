#!/usr/bin/env bats
# T-1772 — Pin the watchdog's FD discipline. Origin: discovered while
# completing T-1771's bats verification. agents/audit/audit.sh:334 forked a
# subshell holding FD 200 (the flock fd from line 321), and its `sleep`
# child reparented to init carrying that fd — keeping the lock held for the
# full AUDIT_TIMEOUT (600s default) and silently aborting every subsequent
# `fw audit` invocation in the same window.
#
# This fixture pins the post-fix invariants:
#   1. After fw audit returns, no orphan sleep "$AUDIT_TIMEOUT" with FD 200 open.
#   2. Two sequential fw audit invocations both produce real output (the
#      second is not blocked by a stale lock).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    TEST_PROJECT="$TEST_TEMP_DIR/proj-watchdog-fd"
    mkdir -p "$TEST_PROJECT/.context/working" \
             "$TEST_PROJECT/.context/locks" \
             "$TEST_PROJECT/.context/audits" \
             "$TEST_PROJECT/.tasks/active" \
             "$TEST_PROJECT/.tasks/completed" \
             "$TEST_PROJECT/.tasks/templates"
    echo "# template" > "$TEST_PROJECT/.tasks/templates/default.md"
    echo "framework_root: $FRAMEWORK_ROOT" > "$TEST_PROJECT/.framework.yaml"
    export PROJECT_ROOT="$TEST_PROJECT"
    # Short timeout so any orphan would be visible — but the fix means
    # there should never be one anyway.
    export FW_AUDIT_TIMEOUT=120
    LOCK_FILE="$TEST_PROJECT/.context/locks/audit.lock"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

# Returns 0 if any process has $LOCK_FILE open. Caller decides what to do.
_anyone_holds_lock() {
    local pids
    pids=$(fuser "$LOCK_FILE" 2>/dev/null | tr -d ' :')
    [ -n "$pids" ]
}

@test "no process holds audit lock after fw audit returns (FD 200 closed in watchdog)" {
    [ -f "$LOCK_FILE" ] || touch "$LOCK_FILE"
    "$FRAMEWORK_ROOT/bin/fw" audit --section structure >/dev/null 2>&1 || true
    # Give the post-exit cleanup a brief moment.
    sleep 1
    if _anyone_holds_lock; then
        local holders
        holders=$(fuser "$LOCK_FILE" 2>/dev/null)
        echo "FAIL: lock still held by: $holders" >&2
        echo "  (T-1772 regression: watchdog inherited FD 200 — orphan sleep keeps the lock)" >&2
        return 1
    fi
}

@test "two sequential fw audit runs both produce structure output (second not stale-locked)" {
    out1=$("$FRAMEWORK_ROOT/bin/fw" audit --section structure 2>&1)
    [[ "$out1" == *"=== STRUCTURE CHECKS ==="* ]]
    [[ "$out1" == *"=== SUMMARY ==="* ]]
    out2=$("$FRAMEWORK_ROOT/bin/fw" audit --section structure 2>&1)
    [[ "$out2" == *"=== STRUCTURE CHECKS ==="* ]]
    [[ "$out2" == *"=== SUMMARY ==="* ]]
    [[ "$out2" != *"Another audit is already running"* ]]
}

@test "audit.sh source closes all inherited fds in watchdog (not just FD 200)" {
    # Regression marker. The first attempt at the fix only closed FD 200. The
    # second attempt walks /proc/self/fd and closes everything >2 — necessary
    # because bats's per-test pipe lives at FD 3 and would otherwise keep the
    # bats orchestrator hung waiting for EOF.
    grep -q '/proc/self/fd' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
    grep -q 'exec \$_n>&-' "$FRAMEWORK_ROOT/agents/audit/audit.sh"
}

@test "no fd > 2 leaks to orphan watchdog after fw audit (pipe-fd-3 regression)" {
    # Run fw audit through a pipe so FD 3 is the pipe write end in the
    # parent shell. If the watchdog inherits it, the pipe never closes.
    "$FRAMEWORK_ROOT/bin/fw" audit --section structure 2>&1 | head -1 >/dev/null
    sleep 1
    # Find any orphan sleep with PPID=1; check none holds a non-/dev/null
    # writable FD other than 0/1/2.
    local leaked=""
    while read -r pid; do
        [ -z "$pid" ] && continue
        for fd in /proc/$pid/fd/*; do
            [ -e "$fd" ] || continue
            n="${fd##*/}"
            case "$n" in 0|1|2) continue ;; esac
            target=$(readlink "$fd" 2>/dev/null)
            [ -z "$target" ] && continue
            case "$target" in /dev/null) continue ;; esac
            leaked="$leaked $pid:fd$n→$target"
        done
    done < <(ps -e -o pid,ppid,cmd | awk '$2==1 && $3=="sleep" {print $1}')
    if [ -n "$leaked" ]; then
        echo "FAIL: orphan watchdog leaked fds:$leaked" >&2
        return 1
    fi
}
