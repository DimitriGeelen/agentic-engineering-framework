#!/usr/bin/env bats
# T-4377: the unit suite is split into tiers declared in tests/unit/tiers.yaml.
#
#   1. with a manifest present, the runner runs only the selected tier's files
#      (FW_UNIT_SUITE_TIER=fast|slow|perf)
#   2. the fast tier writes the root LATEST.yaml (the pre-push ratchet's file);
#      slow writes <report-dir>/slow/, perf writes <report-dir>/perf/
#   3. in the fast tier a skipped test is NOT DETERMINED (exit non-zero, named
#      in files_not_determined); in the slow tier the same skip is not a verdict
#   4. a discovered file missing from the manifest runs in slow with a WARN; a file
#      assigned to two tiers refuses the run (exit 2)
#
# HERMETIC BY CONSTRUCTION: every runner invocation points FW_UNIT_SUITE_DIR at
# a fixture corpus in $BATS_TEST_TMPDIR. The real tests/unit corpus is never run.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/agents/audit/unit-suite.sh"
    WORK="$BATS_TEST_TMPDIR/t4377"
    mkdir -p "$WORK/suite" "$WORK/reports"
    LOCK="$WORK/unit-suite.lock"
    # T-4521: fixture tests are spelled @@test and restored by sed, so bats <1.11 (which
    # scans source text, heredocs included) does not count them as tests of this file.
    sed 's/^@@test/@test/' > "$WORK/suite/fast.bats" <<'EOF'
@@test "fast passes" { true; }
EOF
    sed 's/^@@test/@test/' > "$WORK/suite/skipper.bats" <<'EOF'
@@test "skipper skips" { skip "fixture skip"; }
EOF
    sed 's/^@@test/@test/' > "$WORK/suite/slow.bats" <<'EOF'
@@test "slow passes" { true; }
@@test "slow skips" { skip "fixture skip"; }
EOF
    cat > "$WORK/suite/test_skipper.py" <<'EOF'
import pytest

@pytest.mark.skip(reason="fixture skip")
def test_skipped():
    assert False

def test_passes():
    assert True
EOF
    cat > "$WORK/suite/tiers.yaml" <<'EOF'
schema: unit-tier-manifest-v1
fast:
  - fast.bats
  - skipper.bats
  - test_skipper.py
slow:
  - slow.bats
perf: []
EOF
}

_run_tier() {
    FW_UNIT_SUITE_DIR="$WORK/suite" FW_UNIT_SUITE_REPORT_DIR="$WORK/reports" \
    FW_UNIT_SUITE_LOCK="$LOCK" FW_UNIT_SUITE_TIER="$1" \
        bash "$RUNNER"
}

_report_field() {
    python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2"
}

@test "fast tier writes the root LATEST.yaml, tagged tier: fast, with only its files" {
    _run_tier fast > "$WORK/out.txt" 2>&1 || true
    [ -f "$WORK/reports/LATEST.yaml" ]
    [ "$(_report_field "$WORK/reports/LATEST.yaml" 'd["tier"]')" = "fast" ]
    [ "$(_report_field "$WORK/reports/LATEST.yaml" 'd["legs"]["bats"]["files"]')" = "2" ]
}

@test "fast tier: a skipped test marks its file not determined and fails the leg" {
    run _run_tier fast
    [ "$status" -ne 0 ]
    [ "$(_report_field "$WORK/reports/LATEST.yaml" 'd["legs"]["bats"]["files_not_determined"]')" = "['skipper.bats']" ]
    [ "$(_report_field "$WORK/reports/LATEST.yaml" 'd["legs"]["pytest"]["files_not_determined"]')" = "['test_skipper.py']" ]
    # Like a timeout: the ratchet's completeness rule counts these as timed out.
    [ "$(_report_field "$WORK/reports/LATEST.yaml" 'd["legs"]["bats"]["files_timed_out"]')" = "['skipper.bats']" ]
    [ "$(_report_field "$WORK/reports/LATEST.yaml" 'd["timed_out"]')" = "False" ]
}

@test "slow tier writes under slow/, runs only slow files, and a skip there is not a verdict" {
    run _run_tier slow
    [ "$status" -eq 0 ]
    [ -f "$WORK/reports/slow/LATEST.yaml" ]
    [ ! -f "$WORK/reports/perf/LATEST.yaml" ]
    [ "$(_report_field "$WORK/reports/slow/LATEST.yaml" 'd["tier"]')" = "slow" ]
    [ "$(_report_field "$WORK/reports/slow/LATEST.yaml" 'd["legs"]["bats"]["files"]')" = "1" ]
    [ "$(_report_field "$WORK/reports/slow/LATEST.yaml" 'd["legs"]["bats"]["files_not_determined"]')" = "[]" ]
}

@test "unset tier with a manifest runs fast, slow and perf in turn, each in its own report" {
    cat > "$WORK/suite/tiers.yaml" <<'EOF'
schema: unit-tier-manifest-v1
fast:
  - fast.bats
  - skipper.bats
  - test_skipper.py
slow:
  - slow.bats
perf: []
EOF
    run _run_tier ""
    [ -f "$WORK/reports/LATEST.yaml" ]
    [ -f "$WORK/reports/slow/LATEST.yaml" ]
    [ -f "$WORK/reports/perf/LATEST.yaml" ]
    [ "$(_report_field "$WORK/reports/perf/LATEST.yaml" 'd["tier"]')" = "perf" ]
    [ "$(_report_field "$WORK/reports/perf/LATEST.yaml" 'd["jobs"]')" = "1" ]
    [ "$status" -ne 0 ]
}

@test "a discovered file missing from the manifest runs in slow (not fast), with a WARN, and does not stop the run" {
    # Refusing the run here stopped the whole nightly suite on every new test file (2026-10-19).
    cat > "$WORK/suite/tiers.yaml" <<'EOF'
schema: unit-tier-manifest-v1
fast:
  - fast.bats
slow:
  - slow.bats
perf: []
EOF
    run python3 -I "$REPO_ROOT/agents/audit/unit_tier.py" check --dir "$WORK/suite"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN unassigned (runs in slow until measured): skipper.bats"* ]]
    run python3 -I "$REPO_ROOT/agents/audit/unit_tier.py" files --tier slow --dir "$WORK/suite"
    [[ "$output" == *"/skipper.bats"* ]]
    run python3 -I "$REPO_ROOT/agents/audit/unit_tier.py" files --tier fast --dir "$WORK/suite"
    [[ "$output" != *"skipper.bats"* ]]
    run _run_tier fast
    [ "$status" -ne 2 ]
    [ -f "$WORK/reports/LATEST.yaml" ]
}

@test "a file assigned to two tiers still refuses the run (exit 2, no report)" {
    cat > "$WORK/suite/tiers.yaml" <<'EOF'
schema: unit-tier-manifest-v1
fast:
  - fast.bats
  - skipper.bats
  - test_skipper.py
slow:
  - slow.bats
  - fast.bats
perf: []
EOF
    run _run_tier fast
    [ "$status" -eq 2 ]
    [ ! -f "$WORK/reports/LATEST.yaml" ]
}
