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
    # T-3624: the verdict is the output, not the exit code. In this near-empty
    # fixture the audit exits 1 (empty-set WARNs, T-3105 92deaef0c) or 2 (the
    # reviewer-verdict ledger FAILs where git cannot answer, T-3581 705269221),
    # and a failing assignment aborts the test under bats errexit.
    out1=$("$FRAMEWORK_ROOT/bin/fw" audit --section structure 2>&1) || true
    [[ "$out1" == *"=== STRUCTURE CHECKS ==="* ]]
    [[ "$out1" == *"=== SUMMARY ==="* ]]
    out2=$("$FRAMEWORK_ROOT/bin/fw" audit --section structure 2>&1) || true
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

# T-3809: list fds > 2 (other than /dev/null) held by orphans (PPID=1) that carry
# this run's T3809_MARK in their environment. Scoping by the inherited marker means
# only descendants of this test's own fw audit are inspected — a host-wide scan of
# every orphan `sleep` went red whenever a concurrent audit (another suite file,
# another session's pre-push gate) left one holding a pipe.
_marked_orphan_leaks() {
    local mark="$1" leaked="" pid fd n target
    while read -r pid; do
        [ -z "$pid" ] && continue
        tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -qx "T3809_MARK=$mark" || continue
        for fd in /proc/$pid/fd/*; do
            [ -e "$fd" ] || continue
            n="${fd##*/}"
            case "$n" in 0|1|2) continue ;; esac
            target=$(readlink "$fd" 2>/dev/null)
            [ -z "$target" ] && continue
            case "$target" in /dev/null) continue ;; esac
            leaked="$leaked $pid:fd$n→$target"
        done
    done < <(ps -e -o pid=,ppid= | awk '$2==1 {print $1}')
    echo "$leaked"
}

# Start an orphan (PPID=1) `sleep` holding a pipe at fd 3, with T3809_MARK=$1
# (empty = unmarked). Prints its pid.
_plant_orphan() {
    local mark="$1" pidfile="$TEST_TEMP_DIR/orphan.$RANDOM"
    T3809_MARK="$mark" setsid bash -c 'sleep 60 3> >(cat >/dev/null) & echo $! > "$1"' _ "$pidfile" </dev/null >/dev/null 2>&1
    local i; for i in 1 2 3 4 5 6 7 8 9 10; do [ -s "$pidfile" ] && break; sleep 0.2; done
    cat "$pidfile"
}

@test "no fd > 2 leaks to orphan watchdog after fw audit (pipe-fd-3 regression)" {
    # Run fw audit through a pipe so FD 3 is the pipe write end in the
    # parent shell. If the watchdog inherits it, the pipe never closes.
    export T3809_MARK="audit-$$-$RANDOM"
    "$FRAMEWORK_ROOT/bin/fw" audit --section structure 2>&1 | head -1 >/dev/null
    sleep 1
    local leaked
    leaked=$(_marked_orphan_leaks "$T3809_MARK")
    if [ -n "$leaked" ]; then
        echo "FAIL: orphan watchdog leaked fds:$leaked" >&2
        return 1
    fi
}

@test "T-3809: an unrelated orphan holding a pipe fd does not count as this audit's leak" {
    local pid
    pid=$(_plant_orphan "")
    [ -n "$pid" ]
    leaked=$(_marked_orphan_leaks "audit-$$-$RANDOM")
    kill "$pid" 2>/dev/null || true
    [ -z "$leaked" ]
}

@test "T-3809: control — a marked orphan holding a pipe fd IS detected" {
    local mark="ctl-$$-$RANDOM" pid
    pid=$(_plant_orphan "$mark")
    [ -n "$pid" ]
    leaked=$(_marked_orphan_leaks "$mark")
    kill "$pid" 2>/dev/null || true
    [[ "$leaked" == *"$pid:fd3"* ]]
}
