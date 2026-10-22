#!/usr/bin/env bats
# T-4609: the unit-suite runner's pytest leg imported each test file with
# bytecode writes on, leaving __pycache__/*.pyc beside it — inside the checkout
# the T-4523 tree guard grades. A corpus with no .gitignore for __pycache__
# (t4381's fixture repo) was reported "FAIL the run changed 1 path(s)".
#
# HERMETIC: fixture corpus, git repo and reports live in $BATS_TEST_TMPDIR.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    RUNNER="$REPO_ROOT/agents/audit/unit-suite.sh"
    WORK="$BATS_TEST_TMPDIR/t4609"
    mkdir -p "$WORK/suite" "$WORK/reports"
    cat > "$WORK/suite/test_ok.py" <<'EOF'
def test_ok():
    assert True
EOF
    git -C "$WORK/suite" init -q
    git -C "$WORK/suite" -c user.email=t@t -c user.name=t add -A
    git -C "$WORK/suite" -c user.email=t@t -c user.name=t commit -qm fixture
}

@test "pytest leg leaves no __pycache__ in a clean, un-ignored corpus and the tree guard stays green" {
    run env -u PYTHONDONTWRITEBYTECODE \
            FW_UNIT_SUITE_DIR="$WORK/suite" \
            FW_UNIT_SUITE_REPORT_DIR="$WORK/reports" \
            FW_UNIT_SUITE_LOCK="$WORK/unit-suite.lock" \
            FW_UNIT_SUITE_JOBS=1 "$RUNNER"
    [ "$status" -eq 0 ]
    [ ! -d "$WORK/suite/__pycache__" ]
    [ -z "$(git -C "$WORK/suite" status --porcelain)" ]
    [ "$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["legs"]["pytest"]["exit"])' "$WORK/reports/LATEST.yaml")" = "0" ]
}
