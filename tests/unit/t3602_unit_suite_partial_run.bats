#!/usr/bin/env bats
# T-3602 (OBS-587): a partial (timed-out) unit-suite run must not hide the
# failures it DID record.
#
# OBS-392 (T-3357) made a timed-out run WARN "COULD NOT DETERMINE" as a whole,
# discarding its failure list as a "casualty list". But a test killed by the
# ceiling never prints a `not ok` line (bats) or a `FAILED` summary line
# (pytest): every recorded failure finished and produced a verdict. Only the
# tests the run never reached are undetermined. Because the corpus never
# completed inside 7200s, the WARN branch was the only one that ever ran, and
# 46 red bats files + 6 red pytest files sat invisible for three weeks.
#
# Contract pinned here:
#   1. timed-out + recorded reds      → FAIL, naming them, plus "N of M ran"
#   2. timed-out + zero recorded reds → WARN (not determined), never PASS
#   3. per-file timeouts are NAMED, and a run with one is not green
#   4. the runner records per-file durations and completion (schema v2)
#
# Hermetic: fixture reports + a tiny fixture corpus under $BATS_TEST_TMPDIR.
# The audit check is EXTRACTED from the shipped agents/audit/audit.sh.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/agents/audit/unit-suite.sh"
    WORK="$BATS_TEST_TMPDIR/t3602"
    mkdir -p "$WORK/suite" "$WORK/reports"
}

_run_audit_check() {
    run env FW_UNIT_SUITE_REPORT="$1" REPO_ROOT="$REPO_ROOT" bash -c '
        pass() { echo "PASS|$1"; }
        info() { echo "INFO|$1"; }
        warn() { echo "WARN|$1"; echo "WARNEV|$2"; echo "WARNMIT|$3"; }
        fail() { echo "FAIL|$1"; echo "EVIDENCE|$2"; echo "MITIGATION|$3"; }
        eval "$(sed -n "/^pass_over() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^warn_unenumerable() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        eval "$(sed -n "/^check_unit_suite_report() {/,/^}/p" "$REPO_ROOT/agents/audit/audit.sh")"
        CONTEXT_DIR="/nonexistent-t3602"
        check_unit_suite_report
    '
}

# _write_partial_report <path> <timed_out> <bats-failed-yaml-list> <files_timed_out-yaml-list>
_write_partial_report() {
    local path="$1" timed_out="$2" failed="$3" ftimed="${4:-[]}"
    local n=0
    [ "$failed" != "[]" ] && n=$(echo "$failed" | tr ',' '\n' | wc -l | tr -d ' ')
    cat > "$path" <<EOF
schema: unit-suite-report-v2
task: T-3602
started: '$(date -u +%FT%TZ)'
finished: '$(date -u +%FT%TZ)'
suite_dir: tests/unit
timeout_seconds: 7200
timed_out: $timed_out
runner_exit: 1
legs:
  bats:
    files: 615
    files_completed: 400
    files_timed_out: $ftimed
    files_not_run: 215
    tests: 3000
    failed_count: $n
    skipped: 0
    exit: 124
    failed: $failed
    error: null
  pytest:
    files: 191
    files_completed: 191
    files_timed_out: []
    files_not_run: 0
    tests: 1800
    failed_count: 0
    skipped: 0
    exit: 0
    failed: []
    error: null
EOF
}

# ── 1. the core case: a timed-out run with 2 recorded not-ok lines ──────────

@test "T-3602: timed-out run with 2 recorded reds FAILs, naming both" {
    _write_partial_report "$WORK/partial.yaml" true \
        '["alpha.bats: first red test", "beta.bats: second red test"]'
    _run_audit_check "$WORK/partial.yaml"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit)'
    echo "$output" | grep -q 'alpha.bats: first red test'
    echo "$output" | grep -q 'beta.bats: second red test'
}

@test "T-3602: the partial-run FAIL says how many files ran of how many expected" {
    _write_partial_report "$WORK/partial2.yaml" true \
        '["alpha.bats: first red test", "beta.bats: second red test"]'
    _run_audit_check "$WORK/partial2.yaml"
    # 400 bats + 191 pytest completed of 615 + 191 expected
    echo "$output" | grep -q '591 of 806 file(s) ran'
    # and says the rest is undetermined, not green
    echo "$output" | grep -qi 'not determined'
    ! echo "$output" | grep -q '^PASS|'
}

@test "T-3602: a pre-T-3602 (v1) timed-out report with reds also FAILs" {
    # The live LATEST.yaml at fix time is v1-shaped: no per-file fields. Its
    # recorded reds are verdicts too; the ran-vs-expected count is unknown.
    cat > "$WORK/v1.yaml" <<EOF
schema: unit-suite-report-v1
finished: '$(date -u +%FT%TZ)'
timeout_seconds: 7200
timed_out: true
runner_exit: 1
legs:
  bats: {files: 682, tests: 3599, failed_count: 2, exit: 124, failed: ["one red", "two red"], error: null}
  pytest: {files: 242, tests: 3441, failed_count: 0, exit: 0, failed: [], error: null}
EOF
    _run_audit_check "$WORK/v1.yaml"
    echo "$output" | grep -q '^FAIL|Unit suite (tests/unit)'
    echo "$output" | grep -q 'one red'
    echo "$output" | grep -q 'two red'
    echo "$output" | grep -q 'unknown of 924 file(s) ran'
}

# ── 2. zero recorded reds on a partial run: undetermined, never green ───────

@test "T-3602: timed-out run with ZERO recorded reds WARNs not-determined, never PASS" {
    _write_partial_report "$WORK/partial-clean.yaml" true '[]'
    _run_audit_check "$WORK/partial-clean.yaml"
    echo "$output" | grep -q '^WARN|Unit suite (tests/unit) COULD NOT DETERMINE'
    echo "$output" | grep -q '591 of 806 file(s) ran'
    run grep -qE '^(PASS|FAIL)\|' <<< "$output"
    [ "$status" -ne 0 ]
}

# ── 3. per-file timeouts are named and never read as green ──────────────────

@test "T-3602: a completed run with a per-file timeout and no reds WARNs, naming the file" {
    _write_partial_report "$WORK/ftimeout.yaml" false '[]' '["slow_suite.bats"]'
    _run_audit_check "$WORK/ftimeout.yaml"
    echo "$output" | grep -q '^WARN|'
    echo "$output" | grep -q 'slow_suite.bats'
    run grep -q '^PASS|' <<< "$output"
    [ "$status" -ne 0 ]
}

@test "T-3602: a per-file timeout is named in the FAIL when reds were also recorded" {
    _write_partial_report "$WORK/ftimeout-red.yaml" false '["gamma.bats: red"]' '["slow_suite.bats"]'
    _run_audit_check "$WORK/ftimeout-red.yaml"
    echo "$output" | grep -q '^FAIL|'
    echo "$output" | grep -q 'gamma.bats: red'
    echo "$output" | grep -q 'slow_suite.bats'
}

# ── 4. runner: per-file durations, completion, per-file timeout (v2) ────────

@test "T-3602: runner records per-file durations, completion, and per-file timeouts" {
    cat > "$WORK/suite/fast.bats" <<'EOF'
@test "fast ok" { true; }
@test "fast red" { false; }
EOF
    cat > "$WORK/suite/slow.bats" <<'EOF'
@test "slow hangs" { sleep 60; }
EOF
    cat > "$WORK/suite/test_fast.py" <<'EOF'
def test_ok():
    assert True

def test_red():
    assert False
EOF
    run env FW_UNIT_SUITE_DIR="$WORK/suite" FW_UNIT_SUITE_REPORT_DIR="$WORK/reports" \
            FW_UNIT_SUITE_LOCK="$WORK/lock" FW_UNIT_SUITE_TIMEOUT=120 \
            FW_UNIT_SUITE_FILE_TIMEOUT=5 FW_UNIT_SUITE_JOBS=4 "$RUNNER"
    [ "$status" -eq 1 ]
    run python3 - "$WORK/reports/LATEST.yaml" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert d["schema"] == "unit-suite-report-v2", d["schema"]
b, p = d["legs"]["bats"], d["legs"]["pytest"]
assert b["files"] == 2 and b["files_completed"] == 1, b
assert b["files_timed_out"] == ["slow.bats"], b["files_timed_out"]
assert b["files_not_run"] == 0, b
assert any("fast.bats" in f and "fast red" in f for f in b["failed"]), b["failed"]
assert set(b["file_durations"]) == {"fast.bats", "slow.bats"}, b["file_durations"]
assert b["file_durations"]["slow.bats"] >= 4, b["file_durations"]
assert p["files_completed"] == 1 and p["failed_count"] == 1, p
assert any("test_red" in f for f in p["failed"]), p["failed"]
assert "test_fast.py" in p["file_durations"], p
assert d["timed_out"] is False, d["timed_out"]
assert isinstance(d["wall_seconds"], int), d
print("ok")
PY
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "T-3602: runner counts files it never reached when the whole-run ceiling hits" {
    for i in 1 2 3 4; do
        printf '@test "slow %s" { sleep 20; }\n' "$i" > "$WORK/suite/s$i.bats"
    done
    run env FW_UNIT_SUITE_DIR="$WORK/suite" FW_UNIT_SUITE_REPORT_DIR="$WORK/reports" \
            FW_UNIT_SUITE_LOCK="$WORK/lock" FW_UNIT_SUITE_TIMEOUT=8 \
            FW_UNIT_SUITE_PY_RESERVE=1 FW_UNIT_SUITE_FILE_TIMEOUT=60 \
            FW_UNIT_SUITE_JOBS=1 "$RUNNER"
    run python3 - "$WORK/reports/LATEST.yaml" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
b = d["legs"]["bats"]
assert d["timed_out"] is True, d
assert b["files"] == 4 and b["files_completed"] == 0, b
assert b["files_not_run"] + len(b["files_timed_out"]) == 4, b
assert b["files_not_run"] >= 2, b
print("ok")
PY
    [ "$status" -eq 0 ]
}
