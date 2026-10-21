#!/usr/bin/env bats
load ../git_fence  # T-3610: git discovery must not escape a fixture into a repo above the temp dir
# T-4526: tests and tools left ~406 /tmp/aef-* and /tmp/fw-* entries (1.7 GB)
# on the shared host. Each creator removed its temp path on the happy path only.
# These tests take an exit path that skips the rm and check nothing stays, plus
# the unit-suite runner's own leftover report.
#
# HERMETIC: every run gets TMPDIR=$BATS_TEST_TMPDIR/tmp, so the shared /tmp is
# neither read nor written; the runner is pointed at a fixture corpus.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    W="$BATS_TEST_TMPDIR/t4526"
    PRIV="$W/tmp"
    mkdir -p "$PRIV"
}

# ── fw vendor: a set -e abort after the preserve dir exists ──────────────────

@test "fw vendor aborting after the preserve step leaves no fw-vendor-preserve dir" {
    mkdir -p "$W/src/lib" "$W/tgt"
    cp "$FRAMEWORK_ROOT/lib/vendor_preserve.py" "$W/src/lib/"
    echo x > "$W/src/FRAMEWORK.md"
    echo 1.0 > "$W/src/VERSION"
    git -C "$W/tgt" init -q
    # A FILE where the vendor dir goes: `mkdir -p "$dest"` fails under set -e,
    # after the preserve dir was made and before any rm of it is reached.
    echo file > "$W/tgt/.agentic-framework"
    run env TMPDIR="$PRIV" timeout 120 "$FRAMEWORK_ROOT/bin/fw" vendor --source "$W/src" --target "$W/tgt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot create directory"* ]]
    run ls -A "$PRIV"
    [ -z "$output" ]
}

# ── pre-push hook: interrupted mid-audit ─────────────────────────────────────

@test "pre-push hook killed mid-audit leaves no fw-prepush-audit capture" {
    R="$W/repo"
    mkdir -p "$R/agents/audit" "$R/bin" "$R/.context/locks" "$R/.context/working"
    cd "$R"
    git init -q
    git config user.email t4526@local
    git config user.name "T-4526 fixture"
    git config commit.gpgsign false
    # The audit stub interrupts its caller, the shell running the hook body
    # (a ( ... ) subshell since T-4515), the way a Ctrl-C would.
    cat > agents/audit/audit.sh <<'STUB'
#!/bin/bash
echo "=== STRUCTURE CHECKS ==="
kill -TERM "$PPID"
sleep 2
exit 0
STUB
    printf '#!/bin/bash\nexit 0\n' > bin/fw
    chmod +x agents/audit/audit.sh bin/fw
    echo 1.0.0 > VERSION
    git add -A
    git commit -q -m "T-4526: fixture init"
    PROJECT_ROOT="$R" bash "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks >/dev/null 2>&1
    [ -x .git/hooks/pre-push ]
    local sha branch
    sha="$(git rev-parse HEAD)"; branch="$(git rev-parse --abbrev-ref HEAD)"
    run env TMPDIR="$PRIV" bash -c "echo 'refs/heads/$branch $sha refs/heads/$branch 0000000000000000000000000000000000000000' \
        | .git/hooks/pre-push origin http://localhost"
    [ "$status" -ne 0 ]
    [[ "$output" == *"STRUCTURE CHECKS"* ]]
    run ls -A "$PRIV"
    [ -z "$output" ]
}

# ── unit-suite runner: reports new aef-*/fw-* entries ────────────────────────

_runner_fixture() {
    mkdir -p "$W/suite" "$W/reports"
    sed 's/^@@test/@test/' > "$W/suite/a.bats" <<EOF
@@test "fixture" { $1; }
EOF
    cat > "$W/suite/tiers.yaml" <<'EOF'
schema: unit-tier-manifest-v1
fast:
  - a.bats
slow: []
perf: []
EOF
}

_run_runner() {
    env TMPDIR="$PRIV" FW_UNIT_SUITE_TIER=fast FW_UNIT_SUITE_JOBS=1 \
        FW_UNIT_SUITE_DIR="$W/suite" FW_UNIT_SUITE_REPORT_DIR="$W/reports" \
        FW_UNIT_SUITE_LOCK="$W/unit-suite.lock" \
        bash "$FRAMEWORK_ROOT/agents/audit/unit-suite.sh"
}

_leftovers() {
    python3 -c 'import sys, yaml; t = yaml.safe_load(open(sys.argv[1]))["tmp_leftovers"]; print(t["count"], " ".join(t["names"]))' \
        "$W/reports/LATEST.yaml"
}

@test "runner names a fw-* dir a test leaves in TMPDIR" {
    _runner_fixture 'mkdir "$TMPDIR/fw-t4526-leak-1"'
    echo "aef-already-there" > "$PRIV/aef-already-there"   # pre-existing: not counted
    run _run_runner
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN 1 new aef-*/fw-*"* ]]
    run _leftovers
    [ "$output" = "1 fw-t4526-leak-1" ]
    grep -q 'tmp_leftovers=1$' "$W/reports/runs.log"
}

@test "control: a test that cleans up reports zero leftovers" {
    _runner_fixture 'd=$(mktemp -d "$TMPDIR/fw-t4526-XXXXXX"); rm -r "$d"'
    run _run_runner
    [ "$status" -eq 0 ]
    [[ "$output" != *"WARN"*"aef-*/fw-*"* ]]
    run _leftovers
    [ "$output" = "0 " ]
}
