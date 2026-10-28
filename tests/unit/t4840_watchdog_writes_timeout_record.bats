#!/usr/bin/env bats
# T-4840 — a timed-out audit must leave its timeout record and stop, whatever
# bash does with the body's TERM trap. bash 5.2.21 can lose a trap when the
# signal lands while it parses a $(...) (bug-bash 2023-09/msg00058); the body
# then wrote nothing and could carry on. The watchdog now writes the record
# itself before it signals, and KILLs the body after a bounded grace.
#
# The lost trap is simulated with _FW_AUDIT_TEST_IGNORE_TERM=1 (the body
# ignores TERM, which is the worse case: it keeps running, as in the repro).

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
AUDIT="$FRAMEWORK_ROOT/agents/audit/audit.sh"

setup() {
    TMP_T4840="$(mktemp -d)"
    PROJ="$TMP_T4840/proj"
    mkdir -p "$PROJ/.context/working" "$PROJ/.context/locks" \
             "$PROJ/.context/audits" "$PROJ/.tasks/active" \
             "$PROJ/.tasks/completed" "$PROJ/.tasks/templates"
    echo "# template" > "$PROJ/.tasks/templates/default.md"
    TIMING_FILE="$PROJ/.context/audits/full-audit-timing.yaml"
}

teardown() {
    pkill -KILL -f "$PROJ" 2>/dev/null || true
    rm -rf "$TMP_T4840"
}

_audit_procs() {
    # audit.sh processes started for this hermetic project (holder or body).
    local p
    for p in $(pgrep -f "agents/audit/audit.sh" 2>/dev/null); do
        tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -qx "PROJECT_ROOT=$PROJ" && echo "$p"
    done
    return 0
}

@test "t4840: with the TERM trap lost, the watchdog still records timed_out and killed_in_section" {
    env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" FW_AUDIT_FULL_TIMEOUT=3 \
        _FW_AUDIT_TEST_IGNORE_TERM=1 _FW_AUDIT_KILL_GRACE=2 \
        timeout 120 bash "$AUDIT" --output "$TMP_T4840/out" --quiet >/dev/null 2>&1 || rc=$?

    # Stopped by the watchdog's KILL, well inside the outer bound, and the
    # holder still reports the timeout exit.
    [ "${rc:-0}" -eq 124 ]
    [ -f "$TIMING_FILE" ]
    grep -q "timed_out: true" "$TIMING_FILE"
    grep -q "killed_in_section:" "$TIMING_FILE"
    grep -q "kill_source: internal" "$TIMING_FILE"
}

@test "t4840: no audit process remains after the watchdog KILL" {
    env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" FW_AUDIT_FULL_TIMEOUT=3 \
        _FW_AUDIT_TEST_IGNORE_TERM=1 _FW_AUDIT_KILL_GRACE=2 \
        timeout 120 bash "$AUDIT" --output "$TMP_T4840/out" --quiet >/dev/null 2>&1 || true
    # The watchdog re-asserts after the body is gone; give it a moment to exit.
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        [ -z "$(_audit_procs)" ] && break
        sleep 1
    done
    [ -z "$(_audit_procs)" ]
}

@test "t4840: the in-flight marker is removed on exit" {
    env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" FW_AUDIT_FULL_TIMEOUT=3 \
        _FW_AUDIT_TEST_IGNORE_TERM=1 _FW_AUDIT_KILL_GRACE=2 \
        timeout 120 bash "$AUDIT" --output "$TMP_T4840/out" --quiet >/dev/null 2>&1 || true
    sleep 2
    run bash -c "ls -A '$PROJ/.context/audits' | grep -c '^\.audit-inflight'"
    [ "$output" = 0 ]
}

@test "t4840: with the trap intact, the trap's record keeps timed_out (no contradictory write)" {
    env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" FW_AUDIT_FULL_TIMEOUT=3 \
        timeout 120 bash "$AUDIT" --output "$TMP_T4840/out" --quiet >/dev/null 2>&1 || true
    grep -q "timed_out: true" "$TIMING_FILE"
    grep -q "killed_in_section:" "$TIMING_FILE"
    ! grep -q "^  timed_out: false" "$TIMING_FILE" || false
}

@test "t4840: a timeout before the first section is still recorded, as (startup)" {
    # Ceiling 0: the watchdog fires before any section_mark. Under load the t3127
    # 3s ceiling hit this window (startup measured up to 4s at load avg ~83) and
    # no writer had a section to name, so no record was written at all.
    env PROJECT_ROOT="$PROJ" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" FW_AUDIT_FULL_TIMEOUT=0 \
        _FW_AUDIT_KILL_GRACE=2 \
        timeout 120 bash "$AUDIT" --output "$TMP_T4840/out" --quiet >/dev/null 2>&1 || true
    grep -q "timed_out: true" "$TIMING_FILE"
    grep -q 'killed_in_section: "(startup)"' "$TIMING_FILE"
    # A pseudo-phase is not a section measurement.
    ! grep -q 'name: "(startup)"' "$TIMING_FILE" || false
}

@test "t4840: the watchdog writes the record before it signals the body" {
    # Static order pin: record, then TERM, then KILL.
    run awk '/_audit_watchdog_record "\$_wd_name"/{if(!r)r=NR} /kill -TERM \$\$/{if(!t)t=NR} /kill -KILL \$\$/{k=NR} END{print (r && t && k && r<t && t<k) ? "ordered" : "unordered"}' "$AUDIT"
    [ "$output" = ordered ]
}
