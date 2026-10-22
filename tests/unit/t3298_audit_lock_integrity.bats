#!/usr/bin/env bats
# T-3298 / OBS-308 — audit.sh unlinked the flock'd lock path, breaking the
# mutual exclusion it thought it had. flock binds to an open file description
# — an inode, not a path (lib/keylock.py docstring) — so an unlink of a HELD
# lock lets the next process create a new inode at the same path and flock it
# immediately: two audits hold "the" lock at once.
#
# audit.sh had two in-lifecycle unlink routes plus an orphan:
#   1. the flock arm's EXIT trap did `rm -f "$AUDIT_LOCK_FILE"` — every clean
#      exit destroyed the rendezvous point;
#   2. the pre-acquire mtime stale sweep ran BEFORE the arm split, so a
#      section-scoped run (660s threshold) could unlink the lock a full
#      (3000s-budget) run was actively holding, then acquire a fresh inode →
#      double-hold with exit 0 where 75 was owed;
#   3. the timeout watchdog `( sleep N && kill -TERM $$ ) &` was reaped by
#      killing only the subshell — the sleep child reparented to init and
#      lived up to AUDIT_TIMEOUT after a normal exit (observed live:
#      audit.sh(251163) orphaning sleep(251165), OBS-304..307).
#
# Post-fix invariants pinned here: the flock arm never unlinks (lock file and
# inode survive every exit path), the stale sweep lives only in the no-flock
# fallback arm (where unlink IS the release mechanism), contention still
# exits 75 (T-2930 contract), and a normal exit leaves no watchdog sleep.
#
# Hermetic: every test runs against a scratch PROJECT_ROOT, so the lock is
# the scratch project's .context/locks/audit.lock — never the live one. The
# audit is invoked with a section name that matches nothing, so the full
# lock/watchdog lifecycle runs (acquire → watchdog spawn → EXIT trap) in
# ~0.2s without any section work.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ/.context/working" "$PROJ/.context/locks" \
             "$PROJ/.context/audits" "$PROJ/.tasks/active" \
             "$PROJ/.tasks/completed" "$PROJ/.tasks/templates"
    echo "# template" > "$PROJ/.tasks/templates/default.md"
    LOCK="$PROJ/.context/locks/audit.lock"
}

_run_audit() {
    env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$AUDIT" --section t3298-no-such-section --quiet "$@"
}

# ── Defect 1: the flock arm never unlinks ────────────────────────────────────

@test "t3298: lock file survives a completed audit run (EXIT trap no longer unlinks)" {
    command -v flock >/dev/null 2>&1 || skip "flock not available"
    run _run_audit
    [ "$status" -eq 0 ] || { echo "audit failed: $output" >&2; return 1; }
    [ -f "$LOCK" ] || { echo "lock file was unlinked on exit" >&2; return 1; }
}

@test "t3298: lock inode is stable across a full acquire/release cycle (no unlink+recreate)" {
    command -v flock >/dev/null 2>&1 || skip "flock not available"
    touch "$LOCK"
    local ino_before ino_after
    ino_before=$(stat -c %i "$LOCK")
    run _run_audit
    [ "$status" -eq 0 ]
    ino_after=$(stat -c %i "$LOCK")
    [ "$ino_before" = "$ino_after" ] || {
        echo "inode changed $ino_before → $ino_after: the path was unlinked and recreated" >&2
        return 1
    }
}

@test "t3298: old bug shape — stale-mtime lock HELD by a live audit is not swept: contender exits 75, no double-hold" {
    command -v flock >/dev/null 2>&1 || skip "flock not available"
    # Pre-fix reproduction: the shared stale sweep saw mtime > AUDIT_TIMEOUT+60
    # (600+60 for a section-scoped run), unlinked the HELD lock, and the
    # contender then flocked a fresh inode and ran to completion — double-hold,
    # exit 0 where 75 was owed. Post-fix the flock arm has no sweep at all.
    touch -d '2 hours ago' "$LOCK"
    local ino_held
    ino_held=$(stat -c %i "$LOCK")
    exec 201>"$LOCK"
    flock -n 201
    run _run_audit
    exec 201>&-
    [ "$status" -eq 75 ] || {
        echo "expected 75 (did not run), got $status — a 0 here means the contender ACQUIRED alongside the holder" >&2
        return 1
    }
    [ -f "$LOCK" ] || { echo "held lock was unlinked by the contender" >&2; return 1; }
    [ "$ino_held" = "$(stat -c %i "$LOCK")" ] || {
        echo "held lock's inode was replaced — mutual exclusion broken" >&2
        return 1
    }
}

@test "t3298: contention exits 75 with fresh mtime too (T-2930 contract control leg)" {
    command -v flock >/dev/null 2>&1 || skip "flock not available"
    exec 201>"$LOCK"
    flock -n 201
    run _run_audit
    exec 201>&-
    [ "$status" -eq 75 ] || { echo "expected 75, got $status: $output" >&2; return 1; }
}

@test "t3298: after the holder exits, the next audit acquires the SAME inode (rendezvous point persists)" {
    command -v flock >/dev/null 2>&1 || skip "flock not available"
    # Cycle: audit A completes → holder flocks the surviving file → audit B
    # contends (75) → holder releases → audit C acquires. Every acquisition is
    # on one inode; had A unlinked on exit, the holder and C would have held
    # different inodes and B would have run alongside the holder.
    run _run_audit
    [ "$status" -eq 0 ]
    local ino
    ino=$(stat -c %i "$LOCK")
    exec 201>"$LOCK"
    flock -n 201
    run _run_audit
    [ "$status" -eq 75 ]
    exec 201>&-
    run _run_audit
    [ "$status" -eq 0 ]
    [ "$ino" = "$(stat -c %i "$LOCK")" ]
}

# ── Defect 2: no orphaned watchdog sleep after a normal exit ─────────────────

# T-4545: a run's own processes are found by an environment marker that only
# that run carries, never by shape. The previous check matched ANY `sleep 1`
# whose parent is init, host-wide; under the unit suite's parallel run on a
# shared host an unrelated orphan was enough to fail it.
_marked_pids() {
    # One grep over every environ (NUL-separated entries, -z), not a process per
    # pid: a per-pid scan is slow enough on a busy host to distort the polling.
    grep -lzxF "T3298_RUN_MARK=$1" /proc/[0-9]*/environ 2>/dev/null \
        | sed 's#^/proc/\([0-9]*\)/environ$#\1#'
    return 0
}

# Poll until no process carries the marker, up to a deadline generous enough
# for a loaded host. Returns at once when the subtree is gone.
_wait_marked_gone() {
    local mark="$1" deadline=$(( SECONDS + ${2:-30} ))
    while [ -n "$(_marked_pids "$mark")" ]; do
        [ "$SECONDS" -lt "$deadline" ] || return 1
        sleep 0.2
    done
}

@test "t3298: no watchdog sleep survives a normal audit exit" {
    command -v flock >/dev/null 2>&1 || skip "flock not available"
    # T-4397: the watchdog ticks in one-second sleeps (so it can notice a dead lock
    # holder), not one AUDIT_TIMEOUT-long sleep. Every process the audit forks
    # inherits the marker; once the audit has exited, none may remain.
    local mark="t3298-$$-$BATS_TEST_NUMBER-$RANDOM"
    run env T3298_RUN_MARK="$mark" FW_AUDIT_TIMEOUT=5417 PROJECT_ROOT="$PROJ" \
        FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        bash "$AUDIT" --section t3298-no-such-section --quiet
    [ "$status" -eq 0 ]
    # The EXIT trap's TERM is asynchronous; a tick lives one second, so a
    # survivor at the deadline is a real leak, not scheduling delay.
    if ! _wait_marked_gone "$mark" 30; then
        echo "FAIL: watchdog process outlived the audit" >&2
        local pid
        for pid in $(_marked_pids "$mark"); do ps -o pid=,ppid=,args= -p "$pid" >&2; done
        return 1
    fi
}

@test "t3298: watchdog survivor check is not vacuous (negative control)" {
    # A marked process that outlives its parent must be seen, or the test above
    # passes no matter what the watchdog does.
    local mark="t3298-ctl-$$-$RANDOM" pids="" deadline=$(( SECONDS + 30 ))
    ( env T3298_RUN_MARK="$mark" sleep 60 </dev/null >/dev/null 2>&1 & )
    # Wait for the survivor to exist (exec may be slow under load) — the control
    # is that the scan sees it, not that it appears within a fixed time.
    while [ -z "$pids" ] && [ "$SECONDS" -lt "$deadline" ]; do
        pids=$(_marked_pids "$mark"); [ -n "$pids" ] || sleep 0.2
    done
    [ -n "$pids" ] || { echo "marked survivor never seen by _marked_pids" >&2; return 1; }
    run _wait_marked_gone "$mark" 1
    kill $(_marked_pids "$mark") 2>/dev/null || true
    [ "$status" -ne 0 ]
}

@test "t3298: source pin — watchdog TERM trap kills \$! (the live tick), after a no-op fork resets \$!" {
    # T-4545: a pid copied into a variable after `sleep 1 &` leaves a window in
    # which TERM kills the previous, dead tick and orphans the live one.
    grep -q "trap 'kill \$! 2>/dev/null; exit 0' TERM" "$AUDIT"
    ! grep -q '_watchdog_sleep_pid' "$AUDIT" || false
    local noop_line trap_line
    noop_line=$(grep -n '^      : &$' "$AUDIT" | head -1 | cut -d: -f1)
    trap_line=$(grep -n "trap 'kill \$! 2>/dev/null; exit 0' TERM" "$AUDIT" | head -1 | cut -d: -f1)
    [ -n "$noop_line" ] && [ "$noop_line" -lt "$trap_line" ]
}

# ── Fallback arm keeps its own stale sweep (relocated, not lost) ─────────────

@test "t3298: source pin — flock arm's EXIT trap has no rm of the lock; fallback arm keeps sweep and rm-release" {
    # The flock-arm trap must only reap the watchdog. The fallback (no-flock)
    # arm legitimately unlinks: there, the file's existence IS the lock.
    grep -q 'trap "kill \$AUDIT_TIMEOUT_PID 2>/dev/null" EXIT' "$AUDIT"
    if grep -q 'trap "kill \$AUDIT_TIMEOUT_PID 2>/dev/null; rm -f' "$AUDIT"; then
        echo "FAIL: flock arm's EXIT trap still unlinks the lock file" >&2
        return 1
    fi
    # The fallback trap's rm must name the lock file; other operands may follow
    # it (T-4542 added the holder record), so pin the operand, not the trap text.
    grep -Eq "trap \"rm -f '\\\$AUDIT_LOCK_FILE'( '[^']*')*\" EXIT" "$AUDIT"
    # The mtime stale sweep exists exactly once, inside the fallback arm
    # (after the flock-availability split), not shared before it.
    [ "$(grep -c 'lock_age=' "$AUDIT")" -eq 1 ]
    # Order in file: the flock branch begins before the sweep appears.
    local flock_line sweep_line
    flock_line=$(grep -n 'if command -v flock' "$AUDIT" | head -1 | cut -d: -f1)
    sweep_line=$(grep -n 'lock_age=' "$AUDIT" | head -1 | cut -d: -f1)
    [ "$sweep_line" -gt "$flock_line" ]
}

@test "t3298: fallback arm still sweeps a stale crashed-holder pid file (relocated sweep works)" {
    # Build a PATH without flock so audit.sh takes the fallback arm (same
    # technique as t2930). A stale lock file (older than timeout+60) from a
    # crashed holder must be swept so the audit can run — without the
    # relocated sweep, every future audit would exit 75 forever.
    local d="$PROJ/bin" b p
    mkdir -p "$d"
    for b in bash sh dirname basename pwd date stat mkdir rm cat grep sed python3 \
             git tr head cut wc ls mktemp uname awk sort find tail env touch chmod \
             cp mv id hostname sleep kill ps timeout xargs readlink; do
        p=$(command -v "$b" 2>/dev/null) && ln -sf "$p" "$d/$b"
    done
    touch -d '2 hours ago' "$LOCK"
    run env -u LD_PRELOAD PATH="$d" PROJECT_ROOT="$PROJ" \
        FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        "$d/bash" "$AUDIT" --section t3298-no-such-section --quiet
    [ "$status" -eq 0 ] || {
        echo "expected stale sweep + acquire (0), got $status: $output" >&2
        return 1
    }
}

@test "t3298: fallback arm releases the lock on a normal exit (lock file and holder record gone)" {
    # T-4619: in the no-flock arm the file's existence IS the lock, so a normal
    # exit must unlink it — or every later audit exits 75 until the stale sweep.
    # Behavioural counterpart of the source pin above, which matches trap text.
    local d="$PROJ/bin" b p
    mkdir -p "$d"
    for b in bash sh dirname basename pwd date stat mkdir rm cat grep sed python3 \
             git tr head cut wc ls mktemp uname awk sort find tail env touch chmod \
             cp mv id hostname sleep kill ps timeout xargs readlink; do
        p=$(command -v "$b" 2>/dev/null) && ln -sf "$p" "$d/$b"
    done
    rm -f "$LOCK" "$LOCK.holder"
    run env -u LD_PRELOAD PATH="$d" PROJECT_ROOT="$PROJ" \
        FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        "$d/bash" "$AUDIT" --section t3298-no-such-section --quiet
    [ "$status" -eq 0 ] || { echo "expected 0, got $status: $output" >&2; return 1; }
    [ ! -e "$LOCK" ] || { echo "fallback arm left the lock file behind" >&2; return 1; }
    [ ! -e "$LOCK.holder" ] || { echo "fallback arm left the holder record behind" >&2; return 1; }
}

@test "t3298: fallback arm still refuses a FRESH lock file with 75 (sweep does not over-sweep)" {
    local d="$PROJ/bin" b p
    mkdir -p "$d"
    for b in bash sh dirname basename pwd date stat mkdir rm cat grep sed python3 \
             git tr head cut wc ls mktemp uname awk sort find tail env touch chmod \
             cp mv id hostname sleep kill ps timeout xargs readlink; do
        p=$(command -v "$b" 2>/dev/null) && ln -sf "$p" "$d/$b"
    done
    : > "$LOCK"
    run env -u LD_PRELOAD PATH="$d" PROJECT_ROOT="$PROJ" \
        FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        "$d/bash" "$AUDIT" --section t3298-no-such-section --quiet
    [ "$status" -eq 75 ] || { echo "expected 75, got $status: $output" >&2; return 1; }
}

@test "t3298: audit.sh passes bash syntax check" {
    run bash -n "$AUDIT"
    [ "$status" -eq 0 ]
}
