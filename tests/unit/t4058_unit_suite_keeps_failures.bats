#!/usr/bin/env bats
# T-4058: unit-suite.sh deleted every per-file .out on exit (EXIT trap rm -rf
# $RESULTS), so a red test's assertion text was gone and the audit could name
# only the file. The runner now keeps the output of each red file under
# $REPORT_DIR/failures/<run STARTED>/<leg>/, keeps the newest 14 run dirs, and
# names the kept dir in the report (failures_dir).
#
# HERMETIC: the fixture corpus and report dir live in $BATS_TEST_TMPDIR; the real
# tests/unit corpus is never run from here.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/agents/audit/unit-suite.sh"
    WORK="$BATS_TEST_TMPDIR/t4058"
    mkdir -p "$WORK/suite" "$WORK/reports"
}

_write_red_fixture_suite() {
    # T-4570: fixture tests live in files, not heredocs — bats <1.11 scans this file's
    # source text, heredocs included, and aborts on the fixtures as duplicate test names.
    cp "$REPO_ROOT/tests/unit/fixtures/t4058/passing.bats.fixture" "$WORK/suite/passing.bats"
    cp "$REPO_ROOT/tests/unit/fixtures/t4058/failing.bats.fixture" "$WORK/suite/failing.bats"
}

_write_green_fixture_suite() {
    cp "$REPO_ROOT/tests/unit/fixtures/t4058/passing.bats.fixture" "$WORK/suite/passing.bats"
}

_run_runner() {
    run env FW_UNIT_SUITE_DIR="$WORK/suite" \
            FW_UNIT_SUITE_REPORT_DIR="$WORK/reports" \
            FW_UNIT_SUITE_LOCK="$WORK/unit-suite.lock" \
            FW_UNIT_SUITE_JOBS=2 \
        "$RUNNER"
}

_started() {
    python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["started"])' \
        "$WORK/reports/LATEST.yaml"
}

@test "red run keeps the failing file's output and assertion text, not the passing file's" {
    _write_red_fixture_suite
    _run_runner
    [ "$status" -eq 1 ]
    local kept="$WORK/reports/failures/$(_started)/bats"
    [ -f "$kept/failing.bats.out" ]
    [ -f "$kept/failing.bats.meta" ]
    grep -q '^not ok 1 fixture red asserts MARKER-4058' "$kept/failing.bats.out"
    grep -q 'left-4058' "$kept/failing.bats.out"
    if [ -e "$kept/passing.bats.out" ]; then false; fi
}

@test "report names the kept failures directory for that run" {
    _write_red_fixture_suite
    _run_runner
    [ "$status" -eq 1 ]
    local want="failures/$(_started)"
    python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); assert d["failures_dir"]==sys.argv[2], d.get("failures_dir")' \
        "$WORK/reports/LATEST.yaml" "$want"
}

@test "all-green run keeps nothing and writes no failures directory" {
    _write_green_fixture_suite
    _run_runner
    [ "$status" -eq 0 ]
    [ ! -d "$WORK/reports/failures" ]
    python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); assert d["failures_dir"] is None' \
        "$WORK/reports/LATEST.yaml"
}

@test "run dirs are rotated down to the newest 14, including the run that just finished" {
    _write_red_fixture_suite
    local i
    for i in $(seq 1 17); do
        mkdir -p "$WORK/reports/failures/$(printf '2025-01-01T00:%02d:00Z' "$i")/bats"
    done
    _run_runner
    [ "$status" -eq 1 ]
    [ "$(find "$WORK/reports/failures" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 14 ]
    [ -d "$WORK/reports/failures/$(_started)/bats" ]
    # 17 old + this run = 18; the four oldest (01-04) go, 05-17 + this run stay.
    if [ -d "$WORK/reports/failures/2025-01-01T00:04:00Z" ]; then false; fi
    [ -d "$WORK/reports/failures/2025-01-01T00:05:00Z" ]
}

@test "exit code is unchanged by keeping failures: red suite exits 1, green exits 0" {
    _write_red_fixture_suite
    _run_runner
    [ "$status" -eq 1 ]
    rm -rf "$WORK/reports" "$WORK/suite"
    mkdir -p "$WORK/suite" "$WORK/reports"
    _write_green_fixture_suite
    _run_runner
    [ "$status" -eq 0 ]
}
