#!/usr/bin/env bats
load ../git_fence  # T-3610: git discovery must not escape a fixture into a repo above the temp dir
# T-4215 (dimitri-mint-dev P-015): the unit-suite runner killed test files at the
# per-file cap, and every temp dir such a file had made stayed in the shared /tmp —
# its teardown never ran. The runner now gives each file its own TMPDIR under the
# run's results dir and removes it after the file ends, killed or not.
#
# HERMETIC: the runner gets TMPDIR=$BATS_TEST_TMPDIR/tmp and a fixture corpus.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    W="$BATS_TEST_TMPDIR/t4215"
    PRIV="$W/tmp"
    mkdir -p "$PRIV" "$W/suite" "$W/reports"
    cat > "$W/suite/tiers.yaml" <<'EOF'
schema: unit-tier-manifest-v1
fast:
  - a.bats
slow: []
perf: []
EOF
}

_fixture() {
    sed 's/^@@test/@test/' > "$W/suite/a.bats" <<EOF
@@test "fixture" { $1; }
teardown() { [ -n "\${D:-}" ] && rm -rf "\$D"; true; }
EOF
}

_run_runner() {
    env TMPDIR="$PRIV" FW_UNIT_SUITE_TIER=fast FW_UNIT_SUITE_JOBS=1 \
        FW_UNIT_SUITE_FAST_FILE_TIMEOUT=3 \
        FW_UNIT_SUITE_DIR="$W/suite" FW_UNIT_SUITE_REPORT_DIR="$W/reports" \
        FW_UNIT_SUITE_LOCK="$W/unit-suite.lock" \
        timeout 120 bash "$FRAMEWORK_ROOT/agents/audit/unit-suite.sh"
}

_status_of_a() {
    python3 -c 'import sys, yaml; d = yaml.safe_load(open(sys.argv[1])); print(d["legs"]["bats"]["files_timed_out"])' \
        "$W/reports/LATEST.yaml"
}

@test "a file killed at the per-file cap leaves nothing in the caller's TMPDIR" {
    _fixture 'D=$(mktemp -d); echo "$D" > "'"$W"'/made"; sleep 60'
    run _run_runner
    # The fixture was killed by its cap (so its teardown never ran) ...
    run _status_of_a
    [[ "$output" == *"a.bats"* ]]
    # ... the dir it made was under a per-file TMPDIR, not the caller's ...
    made=$(cat "$W/made")
    [ "$(dirname "$made")" != "$PRIV" ]
    [ ! -e "$made" ]
    # ... and the caller's TMPDIR is left exactly as it was: empty.
    run ls -A "$PRIV"
    [ -z "$output" ]
}

@test "control: a file that finishes also leaves nothing, and saw its own TMPDIR" {
    _fixture 'echo "$TMPDIR" > "'"$W"'/seen"; D=$(mktemp -d)'
    run _run_runner
    [ "$status" -eq 0 ]
    seen=$(cat "$W/seen")
    [ "$seen" != "$PRIV" ]
    [ ! -e "$seen" ]
    run ls -A "$PRIV"
    [ -z "$output" ]
}

@test "an aef-*/fw-* leak inside the per-file TMPDIR is still named in the report" {
    _fixture 'mkdir "$TMPDIR/fw-t4215-leak"'
    run _run_runner
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN 1 new aef-*/fw-*"* ]]
    run python3 -c 'import sys, yaml; t = yaml.safe_load(open(sys.argv[1]))["tmp_leftovers"]; print(t["count"], " ".join(t["names"]))' \
        "$W/reports/LATEST.yaml"
    [ "$output" = "1 fw-t4215-leak" ]
    run ls -A "$PRIV"
    [ -z "$output" ]
}
