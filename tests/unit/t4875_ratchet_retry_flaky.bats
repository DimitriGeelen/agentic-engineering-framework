#!/usr/bin/env bats
# T-4875 (T-4866): the pre-push ratchet retries a first-time red file once.
#
# The runner (agents/audit/unit-suite.sh) re-runs each file holding a NEW red
# (not in the ratchet baseline) once, alone, through the same per-file job. A
# pass on the retry is recorded as suspected_flaky + a flakes.jsonl row, and the
# pre-push grade turns it into WARN. A file that fails again stays a NEW red and
# FAILs. More NEW-red files than UNIT_SUITE_FLAKE_RETRY_MAX = no retry at all.
# Baselined reds are never retried. The full audit still FAILs every red.
#
# HERMETIC: fixture corpus, report dir and baseline live in $BATS_TEST_TMPDIR;
# the real tests/unit corpus is never run from here. The audit check is
# EXTRACTED from the shipped agents/audit/audit.sh (same as t3621).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/agents/audit/unit-suite.sh"
    FIX="$REPO_ROOT/tests/unit/fixtures/t4875"
    WORK="$BATS_TEST_TMPDIR/t4875"
    mkdir -p "$WORK/suite" "$WORK/reports" "$WORK/state"
    BASE="$WORK/reports/baseline.yaml"
    FUTURE=$(date -u -d '+10 days' +%F)
    cp "$REPO_ROOT/tests/unit/fixtures/t4058/passing.bats.fixture" "$WORK/suite/passing.bats"
    # A green pytest leg: an empty one is a leg error, which no baseline covers.
    printf 'def test_green():\n    assert True\n' > "$WORK/suite/test_green.py"
}

_suite() { local f; for f in "$@"; do cp "$FIX/$f.bats.fixture" "$WORK/suite/$f.bats"; done; }

# _baseline <name>... — bats entries, unexpired.
_baseline() {
    {
        echo "schema: unit-suite-baseline-v1"
        echo "entries:"
        echo "  - {leg: bats, name: 'unrelated.bats: placeholder', owner: T-9999, expires: '$FUTURE'}"
        local n
        for n in "$@"; do
            echo "  - {leg: bats, name: '$n', owner: T-9999, expires: '$FUTURE'}"
        done
    } > "$BASE"
}

_run_runner() {
    run env FW_UNIT_SUITE_DIR="$WORK/suite" FW_UNIT_SUITE_REPORT_DIR="$WORK/reports" \
            FW_UNIT_SUITE_LOCK="$WORK/unit-suite.lock" FW_UNIT_SUITE_JOBS=2 \
            T4875_STATE="$WORK/state" "$@" "$RUNNER"
}

# _check <sections> — the shipped grader against the fixture report + baseline.
_check() {
    run env FW_UNIT_SUITE_REPORT="$WORK/reports/LATEST.yaml" FW_UNIT_SUITE_BASELINE="$BASE" \
        SECTIONS="$1" REPO_ROOT="$REPO_ROOT" bash -c '
        pass() { echo "PASS|$1"; }
        info() { echo "INFO|$1"; }
        warn() { echo "WARN|$1"; echo "WARNEV|$2"; }
        fail() { echo "FAIL|$1"; echo "EVIDENCE|$2"; }
        eval "$(sed -n "/^pass_over() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^warn_unenumerable() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^_audit_is_prepush_scope() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^check_unit_suite_report() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        CONTEXT_DIR="/nonexistent-t4875"
        check_unit_suite_report
    '
}

_report_py() {
    python3 -c "import sys,yaml; d=yaml.safe_load(open('$WORK/reports/LATEST.yaml')); $1"
}

_no_fail() { ! echo "$output" | grep -q '^FAIL|'; }
_not_retried() { ! grep -q "RETRY bats $1" "$WORK/reports/runs.log"; }

@test "T-4875: a NEW red that passes on its retry grades WARN suspected flaky and is logged" {
    _suite flaky
    _baseline
    _run_runner
    [ "$status" -eq 1 ]                       # the first run's red still counts
    grep -q 'RETRY bats flaky.bats' "$WORK/reports/runs.log"
    _report_py 'f=d["suspected_flaky"]; assert [e["name"] for e in f]==["flaky.bats: fixture flaky FLAKY-4875"], f; assert "flaky.bats: fixture flaky FLAKY-4875" in d["legs"]["bats"]["failed"]'
    # Flake log row, pointing at the first run's kept output.
    [ "$(wc -l < "$WORK/reports/flakes.jsonl")" -eq 1 ]
    local first
    first=$(python3 -c 'import json,sys; r=json.loads(open(sys.argv[1]).readline()); assert r["retry"]=="pass" and r["file"]=="flaky.bats" and r["name"].endswith("FLAKY-4875") and r["run_started"]; print(r["first_output"])' "$WORK/reports/flakes.jsonl")
    grep -q '^not ok 1 fixture flaky FLAKY-4875' "$WORK/reports/$first"
    _check structure
    echo "$output"
    _no_fail
    echo "$output" | grep -q '^WARN|Unit suite.*1 suspected flaky red'
    echo "$output" | grep '^WARNEV|' | grep -q 'flaky.bats: fixture flaky FLAKY-4875'
    # The full audit still FAILs it, naming it as suspected flaky.
    _check ""
    echo "$output" | grep -q '^FAIL|Unit suite'
    echo "$output" | grep '^EVIDENCE|' | grep -q '1 suspected flaky'
}

@test "T-4875: a NEW red that fails again on its retry stays a NEW red and FAILs" {
    _suite broken
    _baseline
    _run_runner
    [ "$status" -eq 1 ]
    grep -q 'RETRY bats broken.bats' "$WORK/reports/runs.log"
    _report_py 'assert d["suspected_flaky"]==[]; r=d["flake_retry"]["retried"]; assert r[0]["file"]=="broken.bats" and r[0]["retry"]!="pass", r'
    [ ! -s "$WORK/reports/flakes.jsonl" ]
    _check structure
    echo "$output"
    echo "$output" | grep -q '^FAIL|Unit suite.*1 NEW red'
    echo "$output" | grep '^EVIDENCE|' | grep -q 'broken.bats: fixture broken BROKEN-4875'
}

@test "T-4875: more NEW-red files than the cap are not retried and FAIL" {
    _suite flaky broken
    _baseline
    _run_runner FW_UNIT_SUITE_FLAKE_RETRY_MAX=1
    [ "$status" -eq 1 ]
    _not_retried flaky.bats
    _not_retried broken.bats
    _report_py 'r=d["flake_retry"]; assert r["retried"]==[] and "over the retry cap of 1" in r["reason"], r; assert d["suspected_flaky"]==[]'
    _check structure
    echo "$output"
    echo "$output" | grep -q '^FAIL|Unit suite.*2 NEW red'
}

@test "T-4875: cap 0 disables the retry" {
    _suite flaky
    _baseline
    _run_runner FW_UNIT_SUITE_FLAKE_RETRY_MAX=0
    _not_retried flaky.bats
    _check structure
    echo "$output" | grep -q '^FAIL|Unit suite.*1 NEW red'
}

@test "T-4875: baselined reds are not retried and keep their WARN" {
    _suite known
    _baseline "known.bats: fixture known KNOWN-4875"
    _run_runner
    [ "$status" -eq 1 ]
    _not_retried known.bats
    _report_py 'assert d["suspected_flaky"]==[] and d["flake_retry"]["candidates"]==0'
    _check structure
    echo "$output"
    _no_fail
    echo "$output" | grep -q '^WARN|Unit suite.*1 BASELINED red'
}

@test "T-4875: a flaky retry does not hide a second, real NEW red in the same run" {
    _suite flaky broken
    _baseline
    _run_runner
    _report_py 'assert [e["file"] for e in d["suspected_flaky"]]==["flaky.bats"], d["suspected_flaky"]'
    _check structure
    echo "$output"
    echo "$output" | grep -q '^FAIL|Unit suite.*1 NEW red'
    echo "$output" | grep '^EVIDENCE|' | grep -q 'BROKEN-4875'
}

@test "T-4875: no baseline means no retry (the audit fails closed on every red)" {
    _suite flaky
    _run_runner
    _not_retried flaky.bats
    _report_py 'assert "no readable baseline" in d["flake_retry"]["reason"]'
}
