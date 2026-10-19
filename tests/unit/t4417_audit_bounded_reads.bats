#!/usr/bin/env bats
# T-4417 — every external read in the audit section path is bounded.
#
# Mechanism (reproduced before the fix, see the task's RCA): the audit reads git /
# python3 output through pipes (`done < <(git ... log)`, `$(python3 ...)`). A read
# waits for EOF, which only comes when the LAST holder of the pipe's write end
# closes it. A producer that leaves a descendant holding its stdout exits, the
# descendant keeps the pipe open, and the read blocks with no child to wait on —
# until the whole-body watchdog fires. A `timeout` on the producer alone cannot
# help: the producer has already exited.
#
# Hermetic: scratch PROJECT_ROOT and scratch lock file; stub `git` on PATH only for
# the end-to-end test. Never the live repo's lock.

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
    # The T-4397 stub: `git log` leaves a background sleep holding the pipe it
    # was given; every other git call is a silent success.
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
}

teardown() {
    if [ -f "$ORPHAN_PID_FILE" ]; then
        kill -KILL "$(cat "$ORPHAN_PID_FILE")" 2>/dev/null || true
    fi
    pkill -KILL -f "t4417-hung-producer" 2>/dev/null || true
}

# Load the bounded runner exactly as audit.sh defines it.
_load_runner() {
    eval "$(awk '
        /^(_audit_timeout_probe|_audit_bounded|git|python3)\(\) \{/ { infn = 1 }
        infn { print }
        infn && /^\}$/ { infn = 0 }
    ' "$AUDIT")"
    declare -F _audit_bounded >/dev/null || { echo "_audit_bounded not defined in audit.sh" >&2; return 1; }
    declare -F git >/dev/null || { echo "git shim not defined in audit.sh" >&2; return 1; }
    declare -F python3 >/dev/null || { echo "python3 shim not defined in audit.sh" >&2; return 1; }
    _audit_timeout_probe
}

@test "t4417: a section whose git producer leaves an orphan on its stdout finishes on its own" {
    command -v flock >/dev/null 2>&1 || skip "flock not available"
    local start=$SECONDS rc=0
    # Watchdog 40 s: before the fix the run blocks until it fires (exit 124).
    env PATH="$STUB:$PATH" PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
        FW_AUDIT_TIMEOUT=40 timeout 90 bash "$AUDIT" --section enforcement --quiet \
        >"$BATS_TEST_TMPDIR/audit.out" 2>&1 || rc=$?
    local took=$(( SECONDS - start ))
    [ -s "$ORPHAN_PID_FILE" ] || { echo "fixture never reached the git log read" >&2; return 1; }
    [ "$rc" -ne 124 ] || { echo "audit blocked until its watchdog (rc=124, ${took}s)" >&2; return 1; }
    [ "$took" -lt 30 ] || { echo "audit took ${took}s" >&2; return 1; }
    flock -n "$LOCK" -c true || false
}

@test "t4417: the runner does not wait for an orphan that holds its stdout" {
    _load_runner
    local start=$SECONDS out
    out=$(_audit_bounded bash -c 'echo hello; sleep 60 &')
    [ "$out" = "hello" ]
    [ $(( SECONDS - start )) -lt 10 ]
}

@test "t4417: a hung producer is stopped at its per-call budget and reported" {
    _load_runner
    [ "${#_AUDIT_TIMEOUT_CMD[@]}" -gt 0 ] || skip "no timeout(1) on this host"
    local start=$SECONDS rc=0
    FW_AUDIT_READ_TIMEOUT=2 _audit_bounded bash -c 'exec -a t4417-hung-producer sleep 60' \
        >"$BATS_TEST_TMPDIR/out" 2>"$BATS_TEST_TMPDIR/err" < /dev/null || rc=$?
    [ "$rc" -eq 124 ]
    [ $(( SECONDS - start )) -lt 15 ]
    grep -q "read budget" "$BATS_TEST_TMPDIR/err"
    # Through a pipe too (the file-backed path).
    rc=0
    local out
    out=$(FW_AUDIT_READ_TIMEOUT=2 _audit_bounded bash -c 'echo partial; exec -a t4417-hung-producer sleep 60' 2>/dev/null) || rc=$?
    [ "$rc" -eq 124 ]
    [ "$out" = "partial" ]
}

@test "t4417: exit codes and output are preserved on the normal path" {
    _load_runner
    local rc=0 out
    out=$(_audit_bounded bash -c 'echo one; exit 3') || rc=$?
    [ "$rc" -eq 3 ]
    [ "$out" = "one" ]
    # stderr stays on stderr when the caller does not merge it.
    out=$(_audit_bounded bash -c 'echo out; echo err >&2' 2>/dev/null)
    [ "$out" = "out" ]
    # `2>&1` keeps the producer's interleaving order.
    out=$(_audit_bounded bash -c 'echo a; echo b >&2; echo c' 2>&1)
    [ "$out" = "$(printf 'a\nb\nc')" ]
    # Stdin reaches the producer (heredoc / pipe consumers).
    out=$(printf 'x\ny\n' | python3 -c 'import sys; print(len(sys.stdin.read().split()))')
    [ "$out" = "2" ]
    # Non-pipe stdout is written straight through.
    git --version > "$BATS_TEST_TMPDIR/v"
    grep -q "git version" "$BATS_TEST_TMPDIR/v"
    # Prefix assignments reach the producer's environment.
    out=$(T4417_PROBE=yes python3 -c 'import os; print(os.environ.get("T4417_PROBE"))')
    [ "$out" = "yes" ]
}

@test "t4417: no temp files are left behind by a normal read" {
    _load_runner
    export TMPDIR="$BATS_TEST_TMPDIR/tmp"
    mkdir -p "$TMPDIR"
    local out
    out=$(git --version)
    out=$(python3 -c 'print(1)' 2>&1)
    [ -z "$(ls -A "$TMPDIR")" ]
}
