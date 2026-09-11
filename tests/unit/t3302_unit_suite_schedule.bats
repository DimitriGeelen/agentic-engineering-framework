#!/usr/bin/env bats
# T-3302 (A6): pin the nightly unit-suite schedule chain.
#
#   1. the runner skips (logged, exit 0) when its overlap lock is held
#   2. a stub run produces the A2 report schema (LATEST.yaml + dated sibling)
#   3. the audit line branches FAIL / WARN-missing / WARN-stale / PASS against
#      fixture reports, and names its corpus ("unit suite (tests/unit)")
#
# HERMETIC BY CONSTRUCTION: every runner invocation points FW_UNIT_SUITE_DIR at
# a tiny fixture corpus in $BATS_TEST_TMPDIR — the real tests/unit corpus is
# NEVER run from here (it is heavy, and its suites spawn `audit.sh --section
# structure`, contending the audit lock this very file may be running under).
# The audit check function is EXTRACTED from the shipped agents/audit/audit.sh
# (same technique as tests/helpers/audit-set-reporting-block.sh) so the
# assertions stay pinned to the file that ships, not to a copy.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/agents/audit/unit-suite.sh"
    WORK="$BATS_TEST_TMPDIR/t3302"
    mkdir -p "$WORK/suite" "$WORK/reports"
    LOCK="$WORK/unit-suite.lock"
}

_write_green_fixture_suite() {
    cat > "$WORK/suite/fixture.bats" <<'EOF'
@test "fixture passes" { true; }
@test "fixture skips" { skip "fixture skip"; true; }
EOF
    cat > "$WORK/suite/test_fixture.py" <<'EOF'
def test_fixture_ok():
    assert True
EOF
}

_write_red_fixture_suite() {
    _write_green_fixture_suite
    cat > "$WORK/suite/red.bats" <<'EOF'
@test "fixture bats red" { false; }
EOF
    cat > "$WORK/suite/test_red.py" <<'EOF'
def test_fixture_py_red():
    assert False
EOF
}

# A corpus whose bats leg CANNOT finish inside the window — the shape that
# starved the pytest leg to 1 second on four consecutive nightlies (T-3359).
_write_overrunning_bats_fixture() {
    cat > "$WORK/suite/slow.bats" <<'EOF'
@test "fixture bats overruns the window" { sleep 30; }
EOF
    # Deliberately slower than the old 1-second starvation floor: under the
    # pre-T-3359 arithmetic this leg is killed and records 0 tests; with the
    # reserve it completes. A trivial test here would pass either way, which is
    # the false-green this whole file is about.
    cat > "$WORK/suite/test_fixture.py" <<'EOF'
import time

def test_fixture_slow_enough_to_starve():
    time.sleep(3)
    assert True
EOF
}

# Read one field out of the emitted report.
_report_field() {
    python3 -c 'import sys,yaml;d=yaml.safe_load(open(sys.argv[1]));
ks=sys.argv[2].split(".")
for k in ks: d=d[k]
print(d)' "$WORK/reports/LATEST.yaml" "$1"
}

_run_runner_budget() {
    run env FW_UNIT_SUITE_DIR="$WORK/suite" \
            FW_UNIT_SUITE_REPORT_DIR="$WORK/reports" \
            FW_UNIT_SUITE_LOCK="$LOCK" \
            FW_UNIT_SUITE_TIMEOUT="$1" \
            FW_UNIT_SUITE_PY_RESERVE="$2" \
        "$RUNNER"
}

_run_runner() {
    run env FW_UNIT_SUITE_DIR="$WORK/suite" \
            FW_UNIT_SUITE_REPORT_DIR="$WORK/reports" \
            FW_UNIT_SUITE_LOCK="$LOCK" \
            FW_UNIT_SUITE_TIMEOUT=120 \
        "$RUNNER"
}

# Extract check_unit_suite_report (+ the emitters it calls) from the shipped
# audit.sh and run it against a fixture report path.
_run_audit_check() {
    run env FW_UNIT_SUITE_REPORT="$1" REPO_ROOT="$REPO_ROOT" bash -c '
        pass() { echo "PASS|$1"; }
        info() { echo "INFO|$1"; }
        warn() { echo "WARN|$1"; echo "WARNEV|$2"; echo "WARNMIT|$3"; }
        fail() { echo "FAIL|$1"; echo "EVIDENCE|$2"; }
        eval "$(sed -n "/^pass_over() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^warn_unenumerable() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^check_unit_suite_report() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        CONTEXT_DIR="/nonexistent-t3302"
        check_unit_suite_report
    '
}

# Fixture report writer: _write_report <path> <failed_count> <runner_exit> <finished-iso>
_write_report() {
    local path="$1" failed="$2" rc="$3" finished="$4" timed_out="${5:-false}"
    local names="[]"
    [ "$failed" -gt 0 ] && names='["fixture red one", "fixture red two"]'
    cat > "$path" <<EOF
schema: unit-suite-report-v1
task: T-3302
started: '$finished'
finished: '$finished'
suite_dir: tests/unit
timeout_seconds: 7200
timed_out: $timed_out
runner_exit: $rc
legs:
  bats:
    files: 615
    tests: 5000
    failed_count: $failed
    skipped: 3
    exit: $rc
    failed: $names
    error: null
  pytest:
    files: 191
    tests: 1800
    failed_count: 0
    skipped: 2
    exit: 0
    failed: []
    error: null
EOF
}

_now_iso()   { date -u +%FT%TZ; }
_stale_iso() { date -u -d '60 hours ago' +%FT%TZ; }

# ── 1. overlap lock: skip-if-held, logged, exit 0 ────────────────────────────

@test "t3302 runner skips with exit 0 when its overlap lock is held" {
    _write_green_fixture_suite
    # Hold the lock from a background flock, then wait until it is really held.
    flock -x "$LOCK" -c 'sleep 20' &
    HOLDER=$!
    for _ in $(seq 1 50); do
        flock -n "$LOCK" -c true 2>/dev/null || break
        sleep 0.1
    done
    _run_runner
    kill "$HOLDER" 2>/dev/null || true
    [ "$status" -eq 0 ]
    [[ "$output" == *"lock held"* ]]
    [[ "$output" == *"skipping"* ]]
}

@test "t3302 lock-held skip is LOGGED and writes no report" {
    _write_green_fixture_suite
    flock -x "$LOCK" -c 'sleep 20' &
    HOLDER=$!
    for _ in $(seq 1 50); do
        flock -n "$LOCK" -c true 2>/dev/null || break
        sleep 0.1
    done
    _run_runner
    kill "$HOLDER" 2>/dev/null || true
    [ "$status" -eq 0 ]
    grep -q "SKIP lock-held" "$WORK/reports/runs.log"
    [ ! -f "$WORK/reports/LATEST.yaml" ]
}

# ── 2. stub run: A2 report schema ────────────────────────────────────────────

@test "t3302 stub run writes LATEST.yaml + dated sibling with the A2 schema" {
    _write_green_fixture_suite
    _run_runner
    [ "$status" -eq 0 ]
    [ -f "$WORK/reports/LATEST.yaml" ]
    [ -f "$WORK/reports/$(date -u +%F).yaml" ]
    python3 - "$WORK/reports/LATEST.yaml" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert d["schema"] == "unit-suite-report-v1"
for k in ("started", "finished", "runner_exit", "timeout_seconds", "timed_out"):
    assert k in d, k
for leg in ("bats", "pytest"):
    l = d["legs"][leg]
    for k in ("files", "tests", "failed_count", "skipped", "exit", "failed"):
        assert k in l, "%s.%s" % (leg, k)
assert d["runner_exit"] == 0
assert d["legs"]["bats"]["files"] == 1
assert d["legs"]["bats"]["tests"] == 2
assert d["legs"]["bats"]["skipped"] == 1
assert d["legs"]["bats"]["failed_count"] == 0
assert d["legs"]["pytest"]["files"] == 1
assert d["legs"]["pytest"]["tests"] == 1
assert d["legs"]["pytest"]["failed_count"] == 0
PY
}

@test "t3302 stub run records failed test NAMES on both legs and exits non-zero" {
    _write_red_fixture_suite
    _run_runner
    [ "$status" -eq 1 ]
    python3 - "$WORK/reports/LATEST.yaml" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert d["runner_exit"] == 1
assert d["legs"]["bats"]["failed_count"] == 1
assert "fixture bats red" in d["legs"]["bats"]["failed"]
assert d["legs"]["pytest"]["failed_count"] == 1
assert any("test_fixture_py_red" in n for n in d["legs"]["pytest"]["failed"])
PY
}

# ── 3. audit branches against fixture reports ────────────────────────────────

# ── 2b. T-3359: leg 1 must not be able to starve leg 2 ───────────────────────
#
# The legs share one wall-clock window. _remaining() floors at 1, so a bats leg
# that consumed the whole budget handed pytest `timeout 1`. Measured on four
# consecutive nightlies: `pytest: files: 201, tests: 0, exit: 124` — 2706
# collected tests given one second, reported as a leg with zero failures.

@test "T-3359: a bats leg that overruns still leaves the pytest leg its reserve" {
    _write_overrunning_bats_fixture
    # window 15s, reserve 8s -> bats capped at ~7s, pytest must still get ~8s.
    _run_runner_budget 15 8
    [ -f "$WORK/reports/LATEST.yaml" ]

    # THE assertion: leg 2's grant is above the old starvation floor of 1.
    run _report_field 'legs.pytest.budget_seconds'
    [ "$status" -eq 0 ]
    [ "$output" -gt 1 ]

    # and leg 1 was capped short of the whole window, which is what frees it
    run _report_field 'legs.bats.budget_seconds'
    [ "$output" -lt 15 ]
}

@test "T-3359: the starved pytest leg actually MEASURES its tests, not zero" {
    # The point of the reserve is not a bigger number in the report — it is that
    # leg 2 produces a real measurement while leg 1 is still overrunning.
    _write_overrunning_bats_fixture
    _run_runner_budget 15 8
    run _report_field 'legs.pytest.tests'
    [ "$status" -eq 0 ]
    [ "$output" -gt 0 ]
}

@test "T-3359 CONTROL: an early-finishing bats leg does not CAP the pytest leg" {
    # A floor without a ceiling. If bats finishes fast, leg 2 inherits everything
    # left over — not merely the reserve. Guards against 'fix' by hard-splitting.
    _write_green_fixture_suite
    _run_runner_budget 60 10
    run _report_field 'legs.pytest.budget_seconds'
    [ "$status" -eq 0 ]
    [ "$output" -gt 10 ]
}

@test "T-3359: a reserve >= the whole window is clamped, not honoured" {
    # Degenerate config must not invert the split and starve leg 1 instead.
    _write_green_fixture_suite
    _run_runner_budget 20 99
    run _report_field 'pytest_reserve_seconds'
    [ "$output" -lt 20 ]
    run _report_field 'legs.bats.budget_seconds'
    [ "$output" -gt 1 ]
}

@test "t3302 audit FAILs when the report lists failures, naming the corpus" {
    _write_report "$WORK/red.yaml" 2 1 "$(_now_iso)"
    _run_audit_check "$WORK/red.yaml"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit): 2 of 6800 unit test(s) RED (T-3302)'
    echo "$output" | grep -q 'fixture red one'
    ! echo "$output" | grep -q '^PASS|'
}

@test "t3302 audit FAILs on runner_exit non-zero even with zero listed failures" {
    _write_report "$WORK/rc.yaml" 0 2 "$(_now_iso)"
    _run_audit_check "$WORK/rc.yaml"
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit)'
    ! echo "$output" | grep -q '^PASS|'
}

# ── 3b. OBS-392: a timed-out run is NOT a verdict ────────────────────────────
#
# The runner has always emitted `timed_out`; the audit never read it, so a run
# killed at its ceiling rendered its casualty list as RED. That FAIL exited the
# audit 2, which reds tests/unit/audit.bats, whose reds enter the next nightly
# report — a loop that stranded 32 commits behind the pre-push gate over three
# days (OBS-394/395). WARN is the honest verdict: nothing was proven either way.

@test "t3302 audit WARNs (never FAILs) when the run timed out, listed reds and all" {
    _write_report "$WORK/timeout.yaml" 2 1 "$(_now_iso)" true
    _run_audit_check "$WORK/timeout.yaml"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^WARN|Unit suite (tests/unit) COULD NOT DETERMINE'
    ! echo "$output" | grep -qE '^(PASS|FAIL)\|'
}

@test "t3302 timed-out WARN says UNMEASURED, names the ceiling, and is not 'just re-run'" {
    _write_report "$WORK/timeout2.yaml" 2 1 "$(_now_iso)" true
    _run_audit_check "$WORK/timeout2.yaml"
    # names the ceiling that was hit, so the reader knows which knob to turn
    echo "$output" | grep -q '7200s ceiling'
    # the corpus is unknown, not green — the WARN must not read as reassurance
    echo "$output" | grep -q 'UNMEASURED, not green'
    # still surfaces the count, but labelled as a casualty list rather than a verdict
    echo "$output" | grep -q 'casualty list, not a verdict'
    # and must not send the reader back into the run that cannot terminate
    echo "$output" | grep -q 'unchanged just re-times-out'
}

@test "t3302 timed-out with ZERO listed failures is still WARN, never PASS" {
    # The dangerous direction: killed early enough to record nothing at all.
    # Silence here is 'never reached', not 'all green'.
    _write_report "$WORK/timeout-empty.yaml" 0 1 "$(_now_iso)" true
    _run_audit_check "$WORK/timeout-empty.yaml"
    echo "$output" | grep -q '^WARN|Unit suite (tests/unit) COULD NOT DETERMINE'
    ! echo "$output" | grep -q '^PASS|'
}

@test "t3302 CONTROL: a COMPLETED run with the same reds still FAILs" {
    # Separates 'fix narrowed the check' from 'fix disabled the check'. Identical
    # report except timed_out: false — this one must still block.
    _write_report "$WORK/completed-red.yaml" 2 1 "$(_now_iso)" false
    _run_audit_check "$WORK/completed-red.yaml"
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit): 2 of 6800 unit test(s) RED (T-3302)'
    ! echo "$output" | grep -q 'COULD NOT DETERMINE'
}

@test "t3302 CONTROL: a report with NO timed_out field keeps its pre-OBS-392 verdict" {
    # Backward compat with report shapes written before the field was consumed:
    # absent must read false, not truthy, or every legacy report silently downgrades.
    _write_report "$WORK/legacy.yaml" 2 1 "$(_now_iso)"
    grep -v '^timed_out:' "$WORK/legacy.yaml" > "$WORK/legacy-nofield.yaml"
    # `! grep ...` in non-final position is a DEAD assertion under bats errexit
    # (tools/bats-dead-negation-lint.py, T-3138) — use run/status so it bites.
    run grep -q 'timed_out' "$WORK/legacy-nofield.yaml"
    [ "$status" -ne 0 ]
    _run_audit_check "$WORK/legacy-nofield.yaml"
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit)'
    ! echo "$output" | grep -q 'COULD NOT DETERMINE'
}

@test "t3302 audit WARNs when the report is missing" {
    _run_audit_check "$WORK/does-not-exist.yaml"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^WARN|Unit suite (tests/unit) NOT CHECKED'
    ! echo "$output" | grep -qE '^(PASS|FAIL)\|'
}

@test "t3302 audit WARNs when the report is older than 48h" {
    _write_report "$WORK/stale.yaml" 0 0 "$(_stale_iso)"
    _run_audit_check "$WORK/stale.yaml"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^WARN|Unit suite (tests/unit) report STALE'
    ! echo "$output" | grep -qE '^(PASS|FAIL)\|'
}

@test "t3302 audit PASSes a fresh clean report, named over the set it examined" {
    _write_report "$WORK/green.yaml" 0 0 "$(_now_iso)"
    _run_audit_check "$WORK/green.yaml"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^PASS|Unit suite (tests/unit) green — examined 6800 unit test(s) (tests/unit)'
    ! echo "$output" | grep -qE '^(WARN|FAIL)\|'
}

@test "t3302 audit routes an unparsable report to WARN, never PASS" {
    printf 'not: [valid: yaml\n' > "$WORK/broken.yaml"
    _run_audit_check "$WORK/broken.yaml"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^WARN|'
    ! echo "$output" | grep -q '^PASS|'
}

# ── 4. corpus-naming parity (A4) on the shipped invariant-suite line ─────────

@test "t3302 shipped audit source names both corpora, not the bare word 'suite'" {
    grep -q 'Invariant suite (tests/lint) green' "$REPO_ROOT/agents/audit/audit.sh"
    grep -q 'Invariant suite (tests/lint): \$_red of \$_total' "$REPO_ROOT/agents/audit/audit.sh"
    grep -q 'Unit suite (tests/unit) green' "$REPO_ROOT/agents/audit/audit.sh"
}
