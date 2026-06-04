#!/usr/bin/env bats
# T-2198: G-066 closure-readiness gauge — covers READY against live repo,
# NOT_READY when each wiring leg is absent, and --strict exit-code semantics.
#
# The synthetic-repo strategy: build a tempdir with `.context/` + selectively
# populated `lib/reviewer/` + `bin/fw` shims so each NOT_READY case isolates
# exactly one failing condition. Avoids touching the live repo.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TMPDIR="$(mktemp -d)"
    cd "$TMPDIR"
    # PROJECT_ROOT takes precedence over auto-discovery in the gauge. The
    # framework's update-task.sh exports PROJECT_ROOT before running
    # ## Verification commands; without unsetting it, synthetic-repo tests
    # would inspect the live repo instead of their tmpdir (and pass when
    # they should fail). Standalone bats invocation didn't see this
    # because no PROJECT_ROOT was inherited.
    unset PROJECT_ROOT
    # All synthetic-repo tests share a common skeleton — `.context/` is the
    # only marker the gauge uses to recognise a project root.
    mkdir -p .context lib/reviewer bin tools
    cp "$REPO_ROOT/tools/g066-readiness.py" tools/g066-readiness.py
    chmod +x tools/g066-readiness.py
}

teardown() {
    [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ] && rm -rf "$TMPDIR"
}

# Helper: write a fully-wired synthetic repo (all 4 conditions met).
_write_wired_repo() {
    cat > lib/reviewer/static_scan.py <<'PY'
class ScanResult:
    auto_ticked: list[dict] = []

def _should_auto_tick(task, ac_idx):
    return False
PY
    cat > lib/reviewer/dispatch_cli.py <<'PY'
def main():
    return 0
PY
    cat > bin/fw <<'SH'
#!/usr/bin/env bash
# --dispatch is forwarded to lib.reviewer.dispatch_cli
exit 0
SH
    chmod +x bin/fw
}

@test "READY: live repo has all four wirings (T-1985 + T-1951)" {
    # Run against actual repo, not synthetic — proves the live state.
    # Pin via --project-root so PROJECT_ROOT-unset (from setup()) doesn't
    # auto-discover the bats tmpdir.
    out=$(python3 "$REPO_ROOT/tools/g066-readiness.py" --json --project-root "$REPO_ROOT" 2>&1)
    [ "$?" -eq 0 ]
    rc=0
    echo "$out" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert d['verdict']=='READY', d; assert d['passing_count']==4, d" || rc=$?
    [ "$rc" -eq 0 ]
}

@test "READY: synthetic repo with all four wirings present" {
    _write_wired_repo
    run python3 tools/g066-readiness.py --json
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"verdict": "READY"'
    echo "$output" | grep -q '"passing_count": 4'
}

@test "NOT_READY: missing _should_auto_tick function" {
    _write_wired_repo
    # Strip the function definition only — keep auto_ticked field intact.
    cat > lib/reviewer/static_scan.py <<'PY'
class ScanResult:
    auto_ticked: list[dict] = []
PY
    run python3 tools/g066-readiness.py --json
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"verdict": "NOT_READY"'
    echo "$output" | grep -q '"auto_tick_function"'
    echo "$output" | grep -q '"ok": false'
}

@test "NOT_READY: missing auto_ticked field declaration" {
    _write_wired_repo
    # Strip the field, keep the function.
    cat > lib/reviewer/static_scan.py <<'PY'
def _should_auto_tick(task, ac_idx):
    return False
PY
    run python3 tools/g066-readiness.py --json
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"verdict": "NOT_READY"'
    echo "$output" | grep -q '"auto_ticked_field"'
}

@test "NOT_READY: bin/fw lacks --dispatch routing" {
    _write_wired_repo
    cat > bin/fw <<'SH'
#!/usr/bin/env bash
# no dispatch routing
exit 0
SH
    chmod +x bin/fw
    run python3 tools/g066-readiness.py --json
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"verdict": "NOT_READY"'
    echo "$output" | grep -q '"dispatch_routing"'
}

@test "NOT_READY: lib/reviewer/dispatch_cli.py absent" {
    _write_wired_repo
    rm lib/reviewer/dispatch_cli.py
    run python3 tools/g066-readiness.py --json
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"verdict": "NOT_READY"'
    echo "$output" | grep -q '"dispatch_cli_module"'
}

@test "--strict exits 1 on NOT_READY" {
    _write_wired_repo
    rm lib/reviewer/dispatch_cli.py
    run python3 tools/g066-readiness.py --json --strict
    [ "$status" -eq 1 ]
}

@test "--strict exits 0 on READY" {
    _write_wired_repo
    run python3 tools/g066-readiness.py --json --strict
    [ "$status" -eq 0 ]
}

@test "exit 2 when project root has no .context/" {
    # Pass an explicit --project-root that has no .context/ — avoids the
    # auto-discovery walking up to a stray /tmp/.context from prior runs.
    EMPTY_ROOT="$(mktemp -d)"
    run python3 tools/g066-readiness.py --json --project-root "$EMPTY_ROOT"
    rm -rf "$EMPTY_ROOT"
    [ "$status" -eq 2 ]
}

@test "JSON shape contract: required fields all present" {
    out=$(python3 "$REPO_ROOT/tools/g066-readiness.py" --json --project-root "$REPO_ROOT")
    rc=0
    echo "$out" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
required = ('gap_id', 'verdict', 'passing_count', 'total_count', 'checks', 'passing', 'failing', 'ready')
for k in required:
    assert k in d, f'missing key: {k}'
assert d['gap_id'] == 'G-066'
assert isinstance(d['checks'], list) and len(d['checks']) == 4
" || rc=$?
    [ "$rc" -eq 0 ]
}

@test "human-readable mode emits VERDICT line" {
    run python3 "$REPO_ROOT/tools/g066-readiness.py" --project-root "$REPO_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "VERDICT:"
}

@test "lib.gaps.gauge_state surfaces verdict to T-2185 handlers" {
    # gauge_state runs the closure_check_command which is `python3 tools/g066-readiness.py --json`
    # — relative path — so we need cwd at REPO_ROOT for it to resolve. Pass Path object
    # (gauge_state's project_root param expects a Path, not a str — lib/gaps.py:_concerns_path).
    out=$(cd "$REPO_ROOT" && python3 -c "from pathlib import Path; from lib.gaps import gauge_state; import json; print(json.dumps(gauge_state('G-066', project_root=Path('$REPO_ROOT'))))")
    rc=0
    echo "$out" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d['has_gauge'], d
assert d['verdict'] == 'READY', d
assert d['gap_id'] == 'G-066', d
" || rc=$?
    [ "$rc" -eq 0 ]
}
