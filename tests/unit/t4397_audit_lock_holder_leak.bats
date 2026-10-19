#!/usr/bin/env bats
# T-4397 — a live audit held the repo's audit lock after its own work was over,
# and TERM could not reach the read it was stuck in.
#
# Mechanism (reproduced before the fix, see the task's RCA):
#   audit.sh takes the flock on fd 200 in the main shell. Every child the audit
#   forks inherits fd 200 — including the process-substitution child of
#   `done < <(git -C "$PROJECT_ROOT" log --oneline)`. A git helper that leaves a
#   background process holding its stdout (here: `sleep`) makes the audit's
#   `while read` block on a pipe whose only writer is an orphan. The audit has
#   no child, the read never returns, and the orphan keeps fd 200 — so the lock
#   stays held after the audit itself is gone.
#
# Hermetic: scratch PROJECT_ROOT and scratch lock file; a stub `git` on PATH
# only for these tests. Never the live repo's lock.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    PROJ="$BATS_TEST_TMPDIR/proj"
    STUB="$BATS_TEST_TMPDIR/stub"
    mkdir -p "$PROJ/.context/working" "$PROJ/.context/locks" \
             "$PROJ/.context/audits" "$PROJ/.tasks/active" \
             "$PROJ/.tasks/completed" "$PROJ/.tasks/templates" "$STUB"
    echo "# template" > "$PROJ/.tasks/templates/default.md"
    LOCK="$PROJ/.context/locks/audit.lock"
    ORPHAN_PID_FILE="$PROJ/orphan.pid"
    # `git log` leaves a background sleep holding the pipe it was given; every
    # other git call is a silent success so the audit reaches the enforcement
    # section's `done < <(git log ...)` read and nothing earlier.
    cat > "$STUB/git" <<EOF
#!/bin/bash
case " \$* " in
    *" log "*)
        echo "abc1234 T-1: fixture commit"
        sleep 300 &
        echo \$! > "$ORPHAN_PID_FILE"
        ;;
esac
exit 0
EOF
    chmod +x "$STUB/git"
    AUDIT_PID=""
}

teardown() {
    if [ -f "$ORPHAN_PID_FILE" ]; then
        kill -KILL "$(cat "$ORPHAN_PID_FILE")" 2>/dev/null || true
    fi
    if [ -n "$AUDIT_PID" ]; then
        kill -KILL "$AUDIT_PID" 2>/dev/null || true
    fi
}

_start_audit() {
    env PATH="$STUB:$PATH" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$AUDIT" --section enforcement --quiet >"$BATS_TEST_TMPDIR/audit.out" 2>&1 &
    AUDIT_PID=$!
}

_wait_for_orphan() {
    local i
    for i in $(seq 1 100); do
        [ -s "$ORPHAN_PID_FILE" ] && return 0
        sleep 0.1
    done
    echo "fixture never reached the blocking read (no orphan pid file)" >&2
    return 1
}

_wait_exit() {
    local pid="$1" limit="$2" i
    for i in $(seq 1 $((limit * 10))); do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 0.1
    done
    return 1
}

@test "t4397: TERM ends an audit blocked on an orphan-held pipe, and the lock is then free" {
    command -v flock >/dev/null 2>&1 || skip "flock not available"
    _start_audit
    _wait_for_orphan
    kill -TERM "$AUDIT_PID"
    _wait_exit "$AUDIT_PID" 15 || { echo "audit ignored TERM while blocked in its read" >&2; return 1; }
    # The holder is gone. The orphan sleep must not keep the lock.
    flock -n "$LOCK" -c true || false
}

@test "t4397: SIGKILL of the audit releases the lock even though its orphan lives on" {
    command -v flock >/dev/null 2>&1 || skip "flock not available"
    _start_audit
    _wait_for_orphan
    kill -KILL "$AUDIT_PID"
    AUDIT_PID=""
    # The holder died: the lock must be free now, not when the orphan exits.
    flock -n "$LOCK" -c true || false
}

@test "t4397: a body orphaned by SIGKILL of its lock holder stops itself (no unlocked double run)" {
    command -v flock >/dev/null 2>&1 || skip "flock not available"
    _start_audit
    _wait_for_orphan
    kill -KILL "$AUDIT_PID"
    AUDIT_PID=""
    # The audit body outlives its holder only until its guard notices; it must
    # then exit even though its read is still blocked on the orphan's pipe.
    local i body_alive=1
    for i in $(seq 1 150); do
        if ! ps -e -o args= | grep -q "[a]udit.sh --section enforcement"; then
            body_alive=0
            break
        fi
        sleep 0.1
    done
    [ "$body_alive" -eq 0 ] || { echo "audit body kept running after its lock holder died" >&2; return 1; }
}
