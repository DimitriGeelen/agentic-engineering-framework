"""T-2225 Slice 2 (T-2227): structural invariants for web/test_app.py test isolation.

Two pytest invariants that fail CI on drift:

  - Invariant A — sentinel namespace pristine: no T-(996|997|998|999) word-boundary
    matches in web/test_app.py. Catches new test authors adding T-997-style sentinels
    instead of the T-Test-NNN namespace introduced in T-2226.

  - Invariant B — file-writing tests use the helper: any test function that BOTH
    writes a file via `.write_text(...)` AND patches a PROJECT_ROOT reference must
    request the `tmp_project_root` fixture (vs reinventing the manual dual-patch
    pattern that drifted in pre-T-2226). Excludes the helper's own definition.

Pivot from artifact spec (T-2225 §3.2 Layer 4):
  The artifact named these as "reviewer detectors" in `lib/reviewer/static_scan.py`.
  Pytest invariants are a strictly-stronger form of the same Layer-4 intent:
  - Reviewer scans are task-scoped → file-level drift can't attribute to a task.
  - Reviewer findings are advisory; pytest invariants block CI immediately.
  - Per L-324: static fixtures decay under daily-scan rewrites; pytest invariants
    are decay-proof (the test file IS the fixture).

Regression-net tests (test_invariant_*_catches_drift) prove the detectors fire
on synthetic drift — these use string fixtures, NOT edits to the live file.
"""
from __future__ import annotations

import ast
import re
from pathlib import Path

# Resolve TEST_APP_PATH from this test's location: tests/unit/<this> → ../../web/test_app.py
TEST_APP_PATH = Path(__file__).resolve().parent.parent.parent / "web" / "test_app.py"

# Regex: word-boundary 3-digit sentinel ids (T-996/997/998/999). NOT matching T-9999.
SENTINEL_RE = re.compile(r"T-(996|997|998|999)\b")

# Markers identifying the dual-patch antipattern.
WRITE_TEXT_RE = re.compile(r"\.write_text\s*\(")
PROJECT_ROOT_PATCH_RE = re.compile(
    r"monkeypatch\.setattr\s*\(\s*[\"']web\.(shared|blueprints\.tasks)\.PROJECT_ROOT[\"']"
)


def _scan_sentinels(source: str) -> list[tuple[int, str]]:
    """Return [(line_num, line_text)] for every line containing a 3-digit sentinel hit."""
    hits: list[tuple[int, str]] = []
    for lineno, line in enumerate(source.splitlines(), start=1):
        if SENTINEL_RE.search(line):
            hits.append((lineno, line.strip()))
    return hits


def _function_uses_tmp_project_root(func: ast.FunctionDef) -> bool:
    """True if `tmp_project_root` is a parameter of this function (request the fixture)."""
    return any(arg.arg == "tmp_project_root" for arg in func.args.args)


def _function_writes_files_and_patches_project_root(func: ast.FunctionDef, source_lines: list[str]) -> bool:
    """True if function body contains BOTH .write_text(...) AND monkeypatch.setattr(...PROJECT_ROOT...)."""
    # Re-derive function source from line range
    start = func.lineno - 1
    end = (func.end_lineno or func.lineno)
    body = "\n".join(source_lines[start:end])
    return bool(WRITE_TEXT_RE.search(body)) and bool(PROJECT_ROOT_PATCH_RE.search(body))


def _is_helper_fixture_definition(func: ast.FunctionDef) -> bool:
    """True if this IS the tmp_project_root fixture itself (excluded from invariant B)."""
    return func.name == "tmp_project_root"


def _scan_dual_patch_drift(source: str) -> list[tuple[int, str]]:
    """Return [(line_num, func_name)] for each function violating Invariant B."""
    violations: list[tuple[int, str]] = []
    tree = ast.parse(source)
    source_lines = source.splitlines()

    # Walk every function definition (top-level and methods).
    for node in ast.walk(tree):
        if not isinstance(node, ast.FunctionDef):
            continue
        if _is_helper_fixture_definition(node):
            continue
        if not _function_writes_files_and_patches_project_root(node, source_lines):
            continue
        if _function_uses_tmp_project_root(node):
            continue
        violations.append((node.lineno, node.name))
    return violations


# =========================================================================
# Live invariants — run against the actual web/test_app.py
# =========================================================================


def test_invariant_a_sentinel_namespace_pristine():
    """No T-(996|997|998|999) word-boundary in web/test_app.py.

    If this fails: someone introduced a numeric T-NNN sentinel (re-creating the
    collision risk that T-2226 closed). Migrate to T-Test-NNN — see the
    convention block at the top of web/test_app.py and the T-2225 artifact
    at docs/reports/T-2225-test-sentinel-isolation.md.
    """
    source = TEST_APP_PATH.read_text()
    hits = _scan_sentinels(source)
    assert not hits, (
        f"web/test_app.py contains {len(hits)} sentinel-namespace drift line(s):\n"
        + "\n".join(f"  line {ln}: {txt[:120]}" for ln, txt in hits)
        + "\nUse T-Test-NNN namespace instead — see T-2225 artifact."
    )


def test_invariant_b_file_writing_tests_use_helper():
    """Any test that writes files + patches PROJECT_ROOT must use tmp_project_root.

    If this fails: someone reinvented the manual dual-patch pattern that T-2226
    consolidated into the `tmp_project_root` helper. Add `tmp_project_root` to
    the test's parameter list and drop the manual monkeypatch.setattr calls.
    """
    source = TEST_APP_PATH.read_text()
    violations = _scan_dual_patch_drift(source)
    assert not violations, (
        f"web/test_app.py has {len(violations)} test function(s) that write files + patch "
        f"PROJECT_ROOT manually instead of using the tmp_project_root helper:\n"
        + "\n".join(f"  line {ln}: def {name}" for ln, name in violations)
        + "\nUse `tmp_project_root` fixture instead — see web/test_app.py:63-79."
    )


# =========================================================================
# Regression-net — synthetic drift fixtures (string-only, no live-file edits)
# =========================================================================


def test_invariant_a_catches_drift():
    """Verify Invariant A's scanner flags a synthetic drift string."""
    synthetic_drift = '(active / "T-997-empty.md").write_text("")'
    hits = _scan_sentinels(synthetic_drift)
    assert len(hits) == 1, f"Invariant A scanner should flag T-997 drift, got {hits}"


def test_invariant_a_ignores_non_drift_ids():
    """Verify Invariant A's scanner does NOT flag T-Test-NNN, T-9999, T-996X, etc."""
    pristine_inputs = [
        '(active / "T-Test-001-empty.md").write_text("")',  # correct namespace
        'resp = client.get("/api/timeline/task/T-9999")',  # 4-digit route-format check
        'T-9961 is a hypothetical 4-digit id',  # 4-digit, NOT word-boundary 996
    ]
    for inp in pristine_inputs:
        hits = _scan_sentinels(inp)
        assert not hits, f"Invariant A should NOT flag pristine input {inp!r}, got {hits}"


def test_invariant_b_catches_drift():
    """Verify Invariant B's scanner flags a synthetic test that reinvents the antipattern."""
    synthetic_drift_source = '''
def test_some_thing(client, tmp_path, monkeypatch):
    (tmp_path / "x.md").write_text("data")
    monkeypatch.setattr("web.blueprints.tasks.PROJECT_ROOT", tmp_path)
    resp = client.get("/x")
'''
    violations = _scan_dual_patch_drift(synthetic_drift_source)
    assert len(violations) == 1, (
        f"Invariant B scanner should flag dual-patch drift, got {violations}"
    )
    assert violations[0][1] == "test_some_thing"


def test_invariant_b_ignores_helper_definition():
    """Verify Invariant B's scanner does NOT flag the tmp_project_root helper itself."""
    helper_source = '''
def tmp_project_root(tmp_path, monkeypatch):
    """The helper fixture itself patches PROJECT_ROOT — should NOT be flagged."""
    (tmp_path / ".tasks" / "active").mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr("web.shared.PROJECT_ROOT", tmp_path)
    monkeypatch.setattr("web.blueprints.tasks.PROJECT_ROOT", tmp_path)
'''
    # Note: this helper DOES NOT call .write_text(), so the AND-condition fails
    # naturally. Even if it did, _is_helper_fixture_definition would skip it.
    violations = _scan_dual_patch_drift(helper_source)
    assert not violations, f"Invariant B should NOT flag the helper itself, got {violations}"


def test_invariant_b_ignores_helper_user():
    """Verify Invariant B's scanner does NOT flag tests that correctly use the helper."""
    correct_pattern_source = '''
def test_correct_user(client, tmp_project_root):
    (tmp_project_root / ".tasks" / "active" / "T-Test-001.md").write_text("data")
    resp = client.get("/")
'''
    violations = _scan_dual_patch_drift(correct_pattern_source)
    # This function writes a file but does NOT call monkeypatch.setattr, so
    # the AND-condition fails and no violation should fire.
    assert not violations, (
        f"Invariant B should NOT flag tests that use the helper, got {violations}"
    )
