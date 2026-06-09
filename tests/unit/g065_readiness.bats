#!/usr/bin/env bats
# T-2299: G-065 closure-readiness gauge — covers READY against live repo,
# NOT_READY when each wiring leg is absent, and --strict exit-code semantics.
#
# Sibling to tests/unit/g066_readiness.bats. Same synthetic-repo strategy:
# build a tempdir with `.context/` + selectively populated
# `agents/context/check-project-boundary.sh` + `bin/fw` so each NOT_READY
# case isolates exactly one failing condition. Avoids touching the live repo.

load ../test_helper

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TMPDIR="$(mktemp -d)"
    cd "$TMPDIR"
    # PROJECT_ROOT takes precedence over auto-discovery in the gauge (L-456).
    # The framework's update-task.sh exports PROJECT_ROOT before running
    # Verification commands; without unsetting it, synthetic-repo tests would
    # inspect the live repo instead of their tmpdir (and pass when they
    # should fail).
    unset PROJECT_ROOT
    mkdir -p .context agents/context bin tools
    cp "$REPO_ROOT/tools/g065-readiness.py" tools/g065-readiness.py
    chmod +x tools/g065-readiness.py
}

teardown() {
    [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ] && rm -rf "$TMPDIR"
}

# Helper: write a fully-wired synthetic repo (all 4 conditions met).
_write_wired_repo() {
    cat > agents/context/check-project-boundary.sh <<'SH'
#!/usr/bin/env bash
# Pattern 4 (T-1702 / G-065): read-side outside-path arguments.
# Detects absolute-path tokens.
READ_ALLOWED_PREFIXES = ('/tmp/', '/usr/', '/etc/')
SH
    chmod +x agents/context/check-project-boundary.sh
    cat > bin/fw <<'SH'
#!/usr/bin/env bash
# T-1707: doctor scope-tagging (host vs project).
host_warnings=0
_scope_breakdown=""
SH
    chmod +x bin/fw
}

@test "READY: live repo has all four wirings (T-1702 + T-1707)" {
    # Run against actual repo. Pin via --project-root so PROJECT_ROOT-unset
    # (from setup()) doesn't auto-discover the bats tmpdir.
    out=$(python3 "$REPO_ROOT/tools/g065-readiness.py" --json --project-root "$REPO_ROOT" 2>&1)
    [ "$?" -eq 0 ]
    rc=0
    echo "$out" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert d['verdict']=='READY', d; assert d['passing_count']==4, d" || rc=$?
    [ "$rc" -eq 0 ]
}

@test "READY: synthetic repo with all four wirings present" {
    _write_wired_repo
    run python3 tools/g065-readiness.py --json
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"verdict": "READY"'
    echo "$output" | grep -q '"passing_count": 4'
}

@test "NOT_READY: boundary hook file absent" {
    _write_wired_repo
    rm agents/context/check-project-boundary.sh
    run python3 tools/g065-readiness.py --json
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"verdict": "NOT_READY"'
    echo "$output" | grep -q '"boundary_hook_exists"'
    echo "$output" | grep -q '"ok": false'
}

@test "NOT_READY: hook missing Pattern 4 / G-065 comment" {
    _write_wired_repo
    # Strip Pattern 4 + G-065 references; keep allowlist intact.
    cat > agents/context/check-project-boundary.sh <<'SH'
#!/usr/bin/env bash
# Other unrelated comments.
READ_ALLOWED_PREFIXES = ('/tmp/', '/usr/', '/etc/')
SH
    run python3 tools/g065-readiness.py --json
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"verdict": "NOT_READY"'
    echo "$output" | grep -q '"pattern_4_comment"'
}

@test "NOT_READY: hook missing READ_ALLOWED_PREFIXES allowlist" {
    _write_wired_repo
    # Keep Pattern 4 + G-065 references; strip allowlist.
    cat > agents/context/check-project-boundary.sh <<'SH'
#!/usr/bin/env bash
# Pattern 4 (T-1702 / G-065): read-side outside-path arguments.
# Allowlist not yet defined.
SH
    run python3 tools/g065-readiness.py --json
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"verdict": "NOT_READY"'
    echo "$output" | grep -q '"read_allowlist"'
}

@test "NOT_READY: bin/fw lacks doctor scope-tagging (T-1707)" {
    _write_wired_repo
    cat > bin/fw <<'SH'
#!/usr/bin/env bash
# scope-tagging not yet wired
SH
    chmod +x bin/fw
    run python3 tools/g065-readiness.py --json
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"verdict": "NOT_READY"'
    echo "$output" | grep -q '"doctor_scope_tagging"'
}

@test "--strict exits 1 on NOT_READY" {
    _write_wired_repo
    rm agents/context/check-project-boundary.sh
    run python3 tools/g065-readiness.py --json --strict
    [ "$status" -eq 1 ]
}

@test "--strict exits 0 on READY" {
    _write_wired_repo
    run python3 tools/g065-readiness.py --json --strict
    [ "$status" -eq 0 ]
}

@test "exit 2 when project root has no .context/" {
    # Pass an explicit --project-root that has no .context/ — avoids the
    # auto-discovery walking up to a stray /tmp/.context from prior runs.
    EMPTY_ROOT="$(mktemp -d)"
    run python3 tools/g065-readiness.py --json --project-root "$EMPTY_ROOT"
    rm -rf "$EMPTY_ROOT"
    [ "$status" -eq 2 ]
}

@test "JSON shape contract: required fields all present" {
    out=$(python3 "$REPO_ROOT/tools/g065-readiness.py" --json --project-root "$REPO_ROOT")
    rc=0
    echo "$out" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
required = ('gap_id', 'verdict', 'passing_count', 'total_count', 'checks', 'passing', 'failing', 'ready')
for k in required:
    assert k in d, f'missing key: {k}'
assert d['gap_id'] == 'G-065'
assert isinstance(d['checks'], list) and len(d['checks']) == 4
" || rc=$?
    [ "$rc" -eq 0 ]
}

@test "human-readable mode emits VERDICT line" {
    run python3 "$REPO_ROOT/tools/g065-readiness.py" --project-root "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "VERDICT:"
}

@test "lib.gaps.gauge_state surfaces verdict to T-2185 handlers" {
    # gauge_state runs the closure_check_command which is `python3 tools/g065-readiness.py --json`
    # — relative path — so we need cwd at REPO_ROOT for it to resolve.
    out=$(cd "$REPO_ROOT" && python3 -c "from pathlib import Path; from lib.gaps import gauge_state; import json; print(json.dumps(gauge_state('G-065', project_root=Path('$REPO_ROOT'))))")
    rc=0
    echo "$out" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d['has_gauge'], d
assert d['verdict'] == 'READY', d
assert d['gap_id'] == 'G-065', d
" || rc=$?
    [ "$rc" -eq 0 ]
}
