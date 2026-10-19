#!/usr/bin/env bats
# T-4381: four accounting faults in agents/audit/unit-suite.sh that made its
# verdicts untrustworthy (external review, T-4376):
#   1. pytest exit 5 ("no tests collected") was graded as success;
#   2. the pytest leg discovered test_*.py only, so *_test.py and tNNNN_*.py
#      files (35 of them, ~700 tests) never ran;
#   3. LAST-COMPLETE.yaml was written for runs with per-file timeouts;
#   4. no report named the commit or tree state it ran against.
#
# HERMETIC: the fixture corpus, its git repo and the report dir all live in
# $BATS_TEST_TMPDIR; the real tests/unit corpus is never run from here.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/agents/audit/unit-suite.sh"
    WORK="$BATS_TEST_TMPDIR/t4381"
    mkdir -p "$WORK/suite" "$WORK/reports"
    # Every fixture suite carries one green bats file so the bats leg is real.
    cat > "$WORK/suite/passing.bats" <<'EOF'
@test "fixture passing test" { true; }
EOF
}

_run_runner() {
    run env FW_UNIT_SUITE_DIR="$WORK/suite" \
            FW_UNIT_SUITE_REPORT_DIR="$WORK/reports" \
            FW_UNIT_SUITE_LOCK="$WORK/unit-suite.lock" \
            FW_UNIT_SUITE_JOBS=2 "$@" \
        "$RUNNER"
}

# _q <python expr over d> — evaluate against LATEST.yaml, print the result.
_q() {
    python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); print(eval(sys.argv[2]))' \
        "$WORK/reports/LATEST.yaml" "$1"
}

# ── 1. empty collection is red ──────────────────────────────────────────────

@test "pytest file that collects nothing is red: leg exit, failed entry, runner exit 1" {
    cat > "$WORK/suite/test_ok.py" <<'EOF'
def test_ok():
    assert True
EOF
    cat > "$WORK/suite/test_nothing.py" <<'EOF'
# a test_*.py with no test in it: pytest exits 5
X = 1
EOF
    _run_runner
    [ "$status" -eq 1 ]
    [ "$(_q 'd["legs"]["pytest"]["exit"]')" != "0" ]
    _q 'd["legs"]["pytest"]["failed"]' | grep -q 'test_nothing.py: collected no tests'
}

@test "control: a module-level skip (pytest exit 5, reports skipped) stays green" {
    cat > "$WORK/suite/test_skipped.py" <<'EOF'
import pytest
pytest.skip("optional dependency absent", allow_module_level=True)
EOF
    cat > "$WORK/suite/test_ok.py" <<'EOF'
def test_ok():
    assert True
EOF
    _run_runner
    [ "$status" -eq 0 ]
    [ "$(_q 'd["legs"]["pytest"]["failed_count"]')" = "0" ]
}

# ── 2. discovery covers every collectable test file ─────────────────────────

@test "discovery runs *_test.py and tNNNN_*.py files, not helpers or conftest" {
    cat > "$WORK/suite/test_plain.py" <<'EOF'
def test_plain():
    assert True
EOF
    cat > "$WORK/suite/t9001_suffix_test.py" <<'EOF'
def test_suffix_red():
    assert "suffix" == "MARKER-4381-suffix"
EOF
    cat > "$WORK/suite/t9002_named_prose.py" <<'EOF'
class TestNamed:
    def test_named_red(self):
        assert "named" == "MARKER-4381-named"
EOF
    cat > "$WORK/suite/_helper.py" <<'EOF'
def test_looks_like_a_test_but_is_a_helper():
    raise SystemExit("helper must not be run")
EOF
    cat > "$WORK/suite/t9003_adapter.py" <<'EOF'
# a helper module with no test definitions
def build():
    return 1
EOF
    cat > "$WORK/suite/conftest.py" <<'EOF'
EOF
    _run_runner
    [ "$status" -eq 1 ]
    [ "$(_q 'd["legs"]["pytest"]["files"]')" = "3" ]
    _q 'd["legs"]["pytest"]["failed"]' | grep -q 't9001_suffix_test.py::test_suffix_red'
    _q 'd["legs"]["pytest"]["failed"]' | grep -q 't9002_named_prose.py::TestNamed::test_named_red'
    _q 'sorted(d["legs"]["pytest"]["file_durations"])' > "$WORK/ran"
    ! grep -q '_helper.py\|t9003_adapter.py\|conftest.py' "$WORK/ran"
}

@test "the live corpus rule: t2974_greenfield_operator_prose.py is in the discovered set" {
    # Pins the discovery function against the real corpus listing (no test is run).
    run bash -c 'source <(sed -n "/^# BEGIN _discover_pytest/,/^# END _discover_pytest/p" "$1"); _discover_pytest "$2"' \
        _ "$RUNNER" "$REPO_ROOT/tests/unit"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '/t2974_greenfield_operator_prose.py$'
    echo "$output" | grep -q '/t3580_judge_cli_test.py$'
    ! echo "$output" | grep -q '/conftest.py$'
    ! echo "$output" | grep -q '/_review_runtime.py$'
    ! echo "$output" | grep -q '/check_handover_suggestion.py$'
}

# ── 3. per-file timeouts keep a run out of LAST-COMPLETE ────────────────────

@test "a run with a per-file timeout does not overwrite LAST-COMPLETE.yaml" {
    echo "prior: complete-run-sentinel" > "$WORK/reports/LAST-COMPLETE.yaml"
    cat > "$WORK/suite/slow.bats" <<'EOF'
@test "fixture sleeps past its per-file cap" { sleep 30; }
EOF
    cat > "$WORK/suite/test_ok.py" <<'EOF'
def test_ok():
    assert True
EOF
    _run_runner FW_UNIT_SUITE_FILE_TIMEOUT=2
    [ "$(_q 'd["legs"]["bats"]["files_timed_out"]')" = "['slow.bats']" ]
    grep -q 'complete-run-sentinel' "$WORK/reports/LAST-COMPLETE.yaml"
}

@test "control: a clean complete run does write LAST-COMPLETE.yaml" {
    cat > "$WORK/suite/test_ok.py" <<'EOF'
def test_ok():
    assert True
EOF
    _run_runner
    [ "$status" -eq 0 ]
    [ -f "$WORK/reports/LAST-COMPLETE.yaml" ]
    cmp -s "$WORK/reports/LATEST.yaml" "$WORK/reports/LAST-COMPLETE.yaml"
}

# ── 4. every report names its revision ──────────────────────────────────────

_git_fixture() {
    git -C "$WORK/suite" init -q
    git -C "$WORK/suite" -c user.email=t@t -c user.name=t add -A
    git -C "$WORK/suite" -c user.email=t@t -c user.name=t commit -qm fixture
}

@test "report carries the HEAD commit and tree=clean for a clean fixture repo" {
    cat > "$WORK/suite/test_ok.py" <<'EOF'
def test_ok():
    assert True
EOF
    _git_fixture
    local sha; sha=$(git -C "$WORK/suite" rev-parse HEAD)
    _run_runner
    [ "$status" -eq 0 ]
    [ "$(_q 'd["revision"]["commit"]')" = "$sha" ]
    [ "$(_q 'd["revision"]["tree"]')" = "clean" ]
    [ "$(_q 'd["schema"]')" = "unit-suite-report-v2" ]
}

@test "report says tree=dirty when the fixture repo has uncommitted changes" {
    cat > "$WORK/suite/test_ok.py" <<'EOF'
def test_ok():
    assert True
EOF
    _git_fixture
    echo "# edit" >> "$WORK/suite/test_ok.py"
    _run_runner
    [ "$status" -eq 0 ]
    [ "$(_q 'd["revision"]["tree"]')" = "dirty" ]
}

@test "outside a git repo the revision is recorded as unknown, not omitted" {
    cat > "$WORK/suite/test_ok.py" <<'EOF'
def test_ok():
    assert True
EOF
    _run_runner GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR"
    [ "$status" -eq 0 ]
    [ "$(_q 'd["revision"]["commit"]')" = "None" ]
    [ "$(_q 'd["revision"]["tree"]')" = "unknown" ]
}
