#!/usr/bin/env bats
# T-4634: tests/integration ran in no gate (T-4596 RCA). Pin the chain that now
# gates it:
#
#   1. agents/audit/integration-suite.sh runs the unit-suite runner into its OWN
#      report dir (.context/audits/integration-suite), never the unit-suite one
#   2. fw audit grades that report with the unit-suite reader, named
#      "Integration suite": FAIL on red, WARN when missing, PASS when clean
#   3. it is not graded at the pre-push scope (no baseline exists for it)
#   4. the cron registry schedules it
#
# HERMETIC: the wrapper is pointed at a tiny fixture corpus and a temp
# PROJECT_ROOT; the real tests/integration corpus is never run from here.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    WRAPPER="$REPO_ROOT/agents/audit/integration-suite.sh"
    WORK="$BATS_TEST_TMPDIR/t4634"
    mkdir -p "$WORK/suite" "$WORK/proj/.context"
}

# Extract the two check functions (+ the emitters they call) from the shipped
# audit.sh, as t3302 does, and run the integration check against a fixture.
_run_integration_check() {
    run env FW_INTEGRATION_SUITE_REPORT="$1" T4634_SCOPE="${2:-}" REPO_ROOT="$REPO_ROOT" bash -c '
        pass() { echo "PASS|$1"; }
        info() { echo "INFO|$1"; }
        warn() { echo "WARN|$1"; echo "WARNEV|$2"; echo "WARNMIT|$3"; }
        fail() { echo "FAIL|$1"; echo "EVIDENCE|$2"; }
        for f in pass_over warn_unenumerable _audit_is_prepush_scope check_unit_suite_report check_integration_suite_report; do
            eval "$(sed -n "/^$f() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        done
        CONTEXT_DIR="/nonexistent-t4634"
        SECTIONS="$T4634_SCOPE"
        check_integration_suite_report
    '
}

_write_report() {
    local path="$1" failed="$2" rc="$3"
    local names="[]" now; now="$(date -u +%FT%TZ)"
    [ "$failed" -gt 0 ] && names='["fixture_integ.bats: integration red one"]'
    cat > "$path" <<EOF
schema: unit-suite-report-v2
task: T-3302
started: '$now'
finished: '$now'
suite_dir: tests/integration
timeout_seconds: 3600
timed_out: false
runner_exit: $rc
legs:
  bats:
    files: 94
    tests: 568
    failed_count: $failed
    skipped: 0
    exit: $rc
    failed: $names
    error: null
  pytest:
    files: 5
    tests: 17
    failed_count: 0
    skipped: 0
    exit: 0
    failed: []
    error: null
EOF
}

@test "t4634 wrapper writes the integration report dir, not the unit-suite one" {
    sed 's/^@@test/@test/' > "$WORK/suite/fixture.bats" <<'EOF'
@@test "fixture passes" { true; }
EOF
    cat > "$WORK/suite/test_fixture.py" <<'EOF'
def test_fixture_ok():
    assert True
EOF
    run env PROJECT_ROOT="$WORK/proj" FW_UNIT_SUITE_DIR="$WORK/suite" \
            FW_UNIT_SUITE_TIMEOUT=120 "$WRAPPER"
    [ "$status" -eq 0 ]
    [ -f "$WORK/proj/.context/audits/integration-suite/LATEST.yaml" ]
    [ ! -e "$WORK/proj/.context/audits/unit-suite" ]
    grep -q '^jobs: 4$' "$WORK/proj/.context/audits/integration-suite/LATEST.yaml"
    grep -q '^file_timeout_seconds: 900$' "$WORK/proj/.context/audits/integration-suite/LATEST.yaml"
}

@test "t4634 wrapper defaults its corpus to tests/integration" {
    grep -qF 'FW_UNIT_SUITE_DIR="${FW_UNIT_SUITE_DIR:-$FRAMEWORK_ROOT/tests/integration}"' "$WRAPPER"
    grep -qF '.context/locks/integration-suite.lock' "$WRAPPER"
}

@test "t4634 audit FAILs integration reds, named as the integration suite" {
    _write_report "$WORK/red.yaml" 1 1
    _run_integration_check "$WORK/red.yaml"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^FAIL|Integration suite (tests/integration): 1 of 585 integration test(s) RED'
    echo "$output" | grep -q 'integration red one'
    ! echo "$output" | grep -q '^PASS|' || false
}

@test "t4634 audit WARNs when the integration report is missing, naming its cron" {
    _run_integration_check "$WORK/absent.yaml"
    echo "$output" | grep -q '^WARN|Integration suite NOT CHECKED'
    echo "$output" | grep -q 'integration-suite-nightly'
    echo "$output" | grep -q 'agents/audit/integration-suite.sh'
}

@test "t4634 audit PASSes a clean integration report" {
    _write_report "$WORK/green.yaml" 0 0
    _run_integration_check "$WORK/green.yaml"
    echo "$output" | grep -q '^PASS|.*Integration suite (tests/integration) green'
    ! echo "$output" | grep -q '^FAIL|' || false
}

@test "t4634 integration suite is not graded at the pre-push scope" {
    _write_report "$WORK/red.yaml" 1 1
    _run_integration_check "$WORK/red.yaml" structure
    echo "$output" | grep -q '^INFO|Integration suite not graded at pre-push'
    ! echo "$output" | grep -q '^FAIL|' || false
}

@test "t4634 audit.sh calls the integration check and the registry schedules it" {
    grep -q '^check_integration_suite_report$' "$REPO_ROOT/agents/audit/audit.sh"
    python3 - "$REPO_ROOT/.context/cron-registry.yaml" <<'EOF'
import sys, yaml
jobs = yaml.safe_load(open(sys.argv[1]))
if isinstance(jobs, dict):
    jobs = jobs.get("jobs", jobs)
job = [j for j in jobs if j.get("id") == "integration-suite-nightly"]
assert job and job[0]["status"] == "active", job
assert job[0]["command"].endswith("agents/audit/integration-suite.sh"), job
EOF
}
