#!/usr/bin/env bats
# T-4450: the unit-suite runner must not hand its own control variables
# (FW_UNIT_SUITE_TIER, FW_UNIT_SUITE_DIR, ...) to the tests it runs. A test that
# starts a nested runner on a fixture corpus inherited tier=fast from the
# nightly and refused (no tiers.yaml) — t4058 red 5/5 on every run.
#
# HERMETIC BY CONSTRUCTION: the runner is pointed at a fixture corpus in
# $BATS_TEST_TMPDIR. The real tests/unit corpus is never run.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/agents/audit/unit-suite.sh"
    WORK="$BATS_TEST_TMPDIR/t4450"
    mkdir -p "$WORK/suite" "$WORK/reports" "$WORK/env"
    cat > "$WORK/suite/dump.bats" <<'EOF'
@test "dump env" { env > "$T4450_ENV_DIR/bats.env"; }
EOF
    cat > "$WORK/suite/test_dump.py" <<'EOF'
import os

def test_dump_env():
    with open(os.path.join(os.environ["T4450_ENV_DIR"], "pytest.env"), "w") as f:
        f.writelines("%s=%s\n" % kv for kv in os.environ.items())
EOF
    cat > "$WORK/suite/tiers.yaml" <<'EOF'
schema: unit-tier-manifest-v1
fast:
  - dump.bats
  - test_dump.py
slow: []
perf: []
EOF
}

_run_fast() {
    T4450_ENV_DIR="$WORK/env" FW_UNIT_SUITE_TIER=fast FW_UNIT_SUITE_JOBS=1 \
    FW_UNIT_SUITE_DIR="$WORK/suite" FW_UNIT_SUITE_REPORT_DIR="$WORK/reports" \
    FW_UNIT_SUITE_LOCK="$WORK/unit-suite.lock" \
        bash "$RUNNER"
}

@test "bats child sees no FW_UNIT_SUITE_* variable, other env passes through" {
    run _run_fast
    [ "$status" -eq 0 ]
    [ -f "$WORK/env/bats.env" ]
    grep -q '^T4450_ENV_DIR=' "$WORK/env/bats.env"
    run grep '^FW_UNIT_SUITE_' "$WORK/env/bats.env"
    [ "$status" -eq 1 ]
}

@test "pytest child sees no FW_UNIT_SUITE_* variable, other env passes through" {
    python3 -c 'import pytest' 2>/dev/null || skip "pytest not installed"
    run _run_fast
    [ "$status" -eq 0 ]
    [ -f "$WORK/env/pytest.env" ]
    grep -q '^T4450_ENV_DIR=' "$WORK/env/pytest.env"
    run grep '^FW_UNIT_SUITE_' "$WORK/env/pytest.env"
    [ "$status" -eq 1 ]
}
