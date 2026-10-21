#!/usr/bin/env bats
# T-4524: the unit-suite runner must not hand an agent session's variables
# (CLAUDECODE=1, CLAUDE_*, TERMLINK_SESSION_ID, FW_DISPATCHED_WORKER, ...) to the
# tests it runs. ring20's clean-room run launched the suite from a Claude Code
# session and every agent-refusal path in every test took its agent branch.
#
# HERMETIC BY CONSTRUCTION: the runner is pointed at a fixture corpus in
# $BATS_TEST_TMPDIR. The real tests/unit corpus is never run.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/agents/audit/unit-suite.sh"
    WORK="$BATS_TEST_TMPDIR/t4524"
    mkdir -p "$WORK/suite" "$WORK/reports" "$WORK/env"
    # T-4521: fixture tests are spelled @@test and restored by sed, so bats <1.11 (which
    # scans source text, heredocs included) does not count them as tests of this file.
    sed 's/^@@test/@test/' > "$WORK/suite/dump.bats" <<'EOF'
@@test "dump env" { env > "$T4524_ENV_DIR/bats.env"; }
EOF
    cat > "$WORK/suite/test_dump.py" <<'EOF'
import os

def test_dump_env():
    with open(os.path.join(os.environ["T4524_ENV_DIR"], "pytest.env"), "w") as f:
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

SESSION_VARS='^(CLAUDECODE|CLAUDE_[A-Z_]*|TERMLINK_SESSION_ID|FW_DISPATCHED_WORKER|FW_SIDECAR_[A-Z_]*|FW_FOCUS_SESSION_KEY|FW_SESSION_SCOPED_FOCUS|FW_CLAUDE_FW_[A-Z_]*)='

_run_fast_in_session() {
    CLAUDECODE=1 CLAUDE_CODE_ENTRYPOINT=cli CLAUDE_CODE_SESSION_ID=t4524 \
    TERMLINK_SESSION_ID=tl-t4524 FW_DISPATCHED_WORKER=1 FW_SIDECAR_AGENT_ID=w4524 \
    FW_FOCUS_SESSION_KEY=k FW_SESSION_SCOPED_FOCUS=1 FW_CLAUDE_FW_SUPERVISED=1 \
    T4524_ENV_DIR="$WORK/env" FW_UNIT_SUITE_TIER=fast FW_UNIT_SUITE_JOBS=1 \
    FW_UNIT_SUITE_DIR="$WORK/suite" FW_UNIT_SUITE_REPORT_DIR="$WORK/reports" \
    FW_UNIT_SUITE_LOCK="$WORK/unit-suite.lock" \
        bash "$RUNNER"
}

@test "bats child sees no agent-session variable; runner exports still pass" {
    run _run_fast_in_session
    [ "$status" -eq 0 ]
    [ -f "$WORK/env/bats.env" ]
    grep -q '^T4524_ENV_DIR=' "$WORK/env/bats.env"
    grep -q '^FW_WATCHTOWER_ENSURE=0$' "$WORK/env/bats.env"
    run grep -E "$SESSION_VARS" "$WORK/env/bats.env"
    [ "$status" -eq 1 ]
}

@test "pytest child sees no agent-session variable; runner exports still pass" {
    python3 -c 'import pytest' 2>/dev/null || skip "pytest not installed"
    run _run_fast_in_session
    [ "$status" -eq 0 ]
    [ -f "$WORK/env/pytest.env" ]
    grep -q '^T4524_ENV_DIR=' "$WORK/env/pytest.env"
    grep -q '^FW_DOCTOR_SMOKE=0$' "$WORK/env/pytest.env"
    run grep -E "$SESSION_VARS" "$WORK/env/pytest.env"
    [ "$status" -eq 1 ]
}
