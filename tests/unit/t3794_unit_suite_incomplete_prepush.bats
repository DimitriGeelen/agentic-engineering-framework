#!/usr/bin/env bats
# T-3794: the pre-push unit-suite ratchet must not grade an INCOMPLETE run.
#
# 2026-10-04: a run interrupted after 2 of 730 bats files sat in LATEST.yaml.
# The ratchet graded only the reds in the 2 files that ran (0 new) → WARN, and
# WARN does not block a push: ~60 commits went out while the previous complete
# run had 18 NEW reds. At pre-push scope an incomplete LATEST now:
#   - falls back to the last COMPLETE run (LAST-COMPLETE.yaml, else the newest
#     complete dated sibling), naming the run it graded, and still counts the
#     reds the incomplete run DID record (a recorded `not ok` is a verdict);
#   - FAILs "COULD NOT DETERMINE" when no complete run is on record.
# Per-file timeouts (T-3801/T-3083) within max(10, 5% of files) are NOT
# incompleteness: such a run is graded as before.
#
# Hermetic: fixture reports under $BATS_TEST_TMPDIR; the check is EXTRACTED
# from the shipped agents/audit/audit.sh (same harness as t3621).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    WORK="$BATS_TEST_TMPDIR/t3794"
    mkdir -p "$WORK/reports"
    FUTURE=$(date -u -d '+10 days' +%F)
    NOW=$(date -u +%FT%TZ)
    BASE="$WORK/b.yaml"
    {
        echo "schema: unit-suite-baseline-v1"
        echo "entries:"
        echo "  - leg: bats"
        echo "    name: 'old.bats: known red'"
        echo "    owner: T-9999"
        echo "    expires: '$FUTURE'"
    } > "$BASE"
}

_run_check() {   # <report> <sections>
    run env FW_UNIT_SUITE_REPORT="$1" FW_UNIT_SUITE_BASELINE="$BASE" SECTIONS="$2" \
        REPO_ROOT="$REPO_ROOT" bash -c '
        pass() { echo "PASS|$1"; }
        info() { echo "INFO|$1"; }
        warn() { echo "WARN|$1"; echo "WARNEV|$2"; }
        fail() { echo "FAIL|$1"; echo "EVIDENCE|$2"; echo "MITIGATION|$3"; }
        eval "$(sed -n "/^pass_over() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^warn_unenumerable() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^_audit_is_prepush_scope() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^check_unit_suite_report() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        CONTEXT_DIR="/nonexistent-t3794"
        check_unit_suite_report
    '
}

# _report <path> <failed-yaml-list> <started> <interrupted> <timed_out>
#         <files> <completed> <not_run> <files_timed_out-yaml-list>
_report() {
    local n=0
    [ "$2" != "[]" ] && n=$(echo "$2" | tr ',' '\n' | wc -l | tr -d ' ')
    local rc=0; [ "$n" -gt 0 ] && rc=1
    cat > "$1" <<EOF
schema: unit-suite-report-v2
task: T-3794
started: '$3'
finished: '$3'
suite_dir: tests/unit
timeout_seconds: 7200
timed_out: $5
interrupted: $4
runner_exit: $rc
legs:
  bats:
    files: $6
    files_completed: $7
    files_timed_out: $9
    files_not_run: $8
    tests: 100
    failed_count: $n
    skipped: 0
    exit: $rc
    failed: $2
    error: null
  pytest:
    files: 2
    files_completed: 2
    files_timed_out: []
    files_not_run: 0
    tests: 20
    failed_count: 0
    skipped: 0
    exit: 0
    failed: []
    error: null
EOF
}

PREPUSH=structure
_refute_out() { ! echo "$output" | grep -q "$1"; }

# The 2026-10-04 shape: interrupted after 2 of 730 files, no reds recorded.
_interrupted_latest() {
    _report "$WORK/reports/LATEST.yaml" '[]' "$NOW" true true 730 2 728 '["a.bats (interrupted)"]'
}

@test "T-3794: pre-push — interrupted LATEST with NO complete run on record FAILs could-not-determine" {
    _interrupted_latest
    _run_check "$WORK/reports/LATEST.yaml" "$PREPUSH"
    echo "$output"
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit) COULD NOT DETERMINE'
    echo "$output" | grep '^EVIDENCE|' | grep -q 'interrupted'
    _refute_out '^PASS|'
}

@test "T-3794: pre-push — interrupted LATEST falls back to LAST-COMPLETE.yaml and its NEW red FAILs" {
    _report "$WORK/reports/LAST-COMPLETE.yaml" '["new.bats: fresh breakage", "old.bats: known red"]' \
        "2026-10-03T02:00:00Z" false false 730 730 0 '[]'
    _interrupted_latest
    _run_check "$WORK/reports/LATEST.yaml" "$PREPUSH"
    echo "$output"
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit).*1 NEW red'
    echo "$output" | grep '^FAIL|' | grep -q 'last COMPLETE run started 2026-10-03T02:00:00Z'
    echo "$output" | grep '^EVIDENCE|' | grep -q 'new.bats: fresh breakage'
}

@test "T-3794: pre-push — fallback with only baselined reds WARNs and names the graded run" {
    _report "$WORK/reports/LAST-COMPLETE.yaml" '["old.bats: known red"]' "$NOW" false false 730 730 0 '[]'
    _interrupted_latest
    _run_check "$WORK/reports/LATEST.yaml" "$PREPUSH"
    echo "$output"
    _refute_out '^FAIL|'
    echo "$output" | grep -q '^WARN|Unit suite (tests/unit) \[graded last COMPLETE run.*1 BASELINED red'
}

@test "T-3794: pre-push — a red the incomplete LATEST DID record is still graded on top of the fallback" {
    _report "$WORK/reports/LAST-COMPLETE.yaml" '[]' "$NOW" false false 730 730 0 '[]'
    _report "$WORK/reports/LATEST.yaml" '["b.bats: recorded before the kill"]' "$NOW" true true 730 2 728 '[]'
    _run_check "$WORK/reports/LATEST.yaml" "$PREPUSH"
    echo "$output"
    echo "$output" | grep -q '^FAIL|.*1 NEW red'
    echo "$output" | grep '^EVIDENCE|' | grep -q 'b.bats: recorded before the kill'
}

@test "T-3794: pre-push — no LAST-COMPLETE.yaml: the newest COMPLETE dated sibling is graded" {
    _report "$WORK/reports/2026-10-02.yaml" '["new.bats: fresh breakage"]' "2026-10-02T02:00:00Z" false false 730 730 0 '[]'
    _report "$WORK/reports/2026-10-03.yaml" '[]' "2026-10-03T02:00:00Z" false true 730 400 330 '[]'
    _interrupted_latest
    _run_check "$WORK/reports/LATEST.yaml" "$PREPUSH"
    echo "$output"
    echo "$output" | grep -q '^FAIL|.*last COMPLETE run started 2026-10-02T02:00:00Z.*1 NEW red'
}

@test "T-3794: pre-push — run ceiling hit with files never reached is incomplete too" {
    _report "$WORK/reports/LATEST.yaml" '[]' "$NOW" false true 730 500 230 '[]'
    _run_check "$WORK/reports/LATEST.yaml" "$PREPUSH"
    echo "$output"
    echo "$output" | grep -q '^FAIL|.*COULD NOT DETERMINE'
}

@test "T-3794: pre-push — files unaccounted for (completed far below files, no not_run) is incomplete" {
    _report "$WORK/reports/LATEST.yaml" '[]' "$NOW" false false 730 2 0 '[]'
    _run_check "$WORK/reports/LATEST.yaml" "$PREPUSH"
    echo "$output"
    echo "$output" | grep -q '^FAIL|.*COULD NOT DETERMINE'
}

@test "T-3794: pre-push — a COMPLETE run with a few per-file timeouts is graded as before (no fallback, no FAIL)" {
    _report "$WORK/reports/LATEST.yaml" '["old.bats: known red"]' "$NOW" false false 730 722 0 \
        '["s1.bats", "s2.bats", "s3.bats", "s4.bats", "s5.bats", "s6.bats", "s7.bats", "s8.bats"]'
    _run_check "$WORK/reports/LATEST.yaml" "$PREPUSH"
    echo "$output"
    _refute_out '^FAIL|'
    _refute_out 'graded last COMPLETE run'
    echo "$output" | grep -q '^WARN|Unit suite (tests/unit): 1 BASELINED red'
}

@test "T-3794: pre-push — per-file timeouts above max(10, 5% of files) make the run incomplete" {
    local list; list="[$(for i in $(seq 1 60); do printf '"s%d.bats", ' "$i"; done | sed 's/, $//')]"
    _report "$WORK/reports/LATEST.yaml" '[]' "$NOW" false false 730 670 0 "$list"
    _run_check "$WORK/reports/LATEST.yaml" "$PREPUSH"
    echo "$output"
    echo "$output" | grep -q '^FAIL|.*COULD NOT DETERMINE'
    echo "$output" | grep '^EVIDENCE|' | grep -q 'per-file timeout'
}

@test "T-3794: pre-push — a clean complete LATEST still PASSes" {
    _report "$WORK/reports/LATEST.yaml" '[]' "$NOW" false false 730 730 0 '[]'
    _run_check "$WORK/reports/LATEST.yaml" "$PREPUSH"
    echo "$output"
    echo "$output" | grep -q '^PASS|'
}

@test "T-3794: other scopes are unchanged — an interrupted no-red run still WARNs, never FAILs" {
    _interrupted_latest
    _run_check "$WORK/reports/LATEST.yaml" ""
    echo "$output"
    _refute_out '^FAIL|'
    echo "$output" | grep -q '^WARN|Unit suite (tests/unit) COULD NOT DETERMINE'
}

@test "T-3794: the runner writes LAST-COMPLETE.yaml only for a complete run" {
    grep -q 'LAST-COMPLETE.yaml' "$REPO_ROOT/agents/audit/unit-suite.sh"
}
