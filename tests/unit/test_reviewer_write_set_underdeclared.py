"""T-2504 (T-2324 IW-4): tests for detect_write_set_underdeclared.

Detector fires when a task declares write_set: but the body references
file paths under known source/governance dirs that are not covered by any
declared glob. Under-declaration is the dangerous error for parallel dispatch;
over-declaration is safe and must NOT be flagged.

Gates (all must hold):
  1. write_set: present and non-empty in frontmatter
  2. Path appears in body with write-indicating context (write verb on line,
     or inside a code-fence block)
  3. Path under a known source/governance directory prefix
  4. No declared write_set glob covers the path (fnmatch check)
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402


# ───────────────────────── Helpers ─────────────────────────


def _run(meta: dict, body: str) -> list[ss.Finding]:
    return ss.detect_write_set_underdeclared(meta, body)


def _ids(findings: list[ss.Finding]) -> list[str]:
    return [f.pattern_id for f in findings]


# ───────────────────────── Gate 1: write_set absent / empty → no finding ─────


def test_no_write_set_key_no_finding():
    meta = {"id": "T-9001", "name": "test task"}
    body = "## Context\nAdds lib/reviewer/new_detector.py via Write tool.\n"
    assert _run(meta, body) == []


def test_empty_write_set_no_finding():
    meta = {"write_set": []}
    body = "## Context\nEdits lib/reviewer/static_scan.py.\n"
    assert _run(meta, body) == []


def test_null_write_set_no_finding():
    meta = {"write_set": None}
    body = "## Context\nUpdates lib/foo.py.\n"
    assert _run(meta, body) == []


# ───────────────────────── Positive: under-declared path flagged ─────────────


def test_under_declared_path_flagged():
    """Body writes lib/reviewer/foo.py; write_set covers only lib/bar.py → CONCERN."""
    meta = {"write_set": ["lib/bar.py"]}
    body = "## Context\nCreate lib/reviewer/foo.py with the new detector.\n"
    findings = _run(meta, body)
    assert len(findings) == 1
    assert findings[0].pattern_id == "write-set-underdeclared"
    assert "lib/reviewer/foo.py" in findings[0].evidence
    assert findings[0].lie_severity == "partial"
    assert findings[0].detection_confidence == "heuristic"


def test_agents_dir_path_flagged():
    """Path under agents/ not covered → flagged."""
    meta = {"write_set": ["lib/*.py"]}
    body = "## Acceptance Criteria\n### Agent\n- [ ] Writes agents/task-create/update-task.sh\n"
    findings = _run(meta, body)
    assert any("agents/task-create/update-task.sh" in f.evidence for f in findings)


def test_multiple_uncovered_paths_each_flagged():
    """Two uncovered paths → two findings."""
    meta = {"write_set": ["lib/foo.py"]}
    body = (
        "## Context\n"
        "Edit lib/bar.py to add helper.\n"
        "Also create tests/unit/test_bar.py.\n"
    )
    findings = _run(meta, body)
    paths_flagged = {f.evidence.split("path=")[1].split("'")[1] for f in findings}
    assert "lib/bar.py" in paths_flagged
    assert "tests/unit/test_bar.py" in paths_flagged


# ───────────────────────── Negative: covered path → no finding ───────────────


def test_covered_by_exact_pattern_no_finding():
    """write_set exactly names the path → no finding."""
    meta = {"write_set": ["lib/reviewer/static_scan.py"]}
    body = "## Context\nEdits lib/reviewer/static_scan.py.\n"
    assert _run(meta, body) == []


def test_covered_by_wildcard_no_finding():
    """write_set glob covers the path via fnmatch → no finding."""
    meta = {"write_set": ["lib/reviewer/*.py"]}
    body = "## Context\nCreate lib/reviewer/new_module.py.\n"
    assert _run(meta, body) == []


def test_covered_by_broad_glob_no_finding():
    """write_set glob lib/*.py covers lib/reviewer/foo.py via fnmatch (* spans /)."""
    meta = {"write_set": ["lib/*.py"]}
    body = "## Context\nAdd lib/reviewer/foo.py with IW-4 detector.\n"
    assert _run(meta, body) == []


def test_covered_by_dir_glob_no_finding():
    """write_set: ['tests/**'] covers tests/unit/test_foo.py."""
    meta = {"write_set": ["tests/**"]}
    body = "## Context\nWrite tests/unit/test_foo.py unit tests.\n"
    assert _run(meta, body) == []


# ───────────────────────── Gate 2: write-context required ────────────────────


def test_path_without_write_verb_not_flagged():
    """Path in body but no write verb on the line → not flagged (conservative)."""
    meta = {"write_set": ["lib/bar.py"]}
    body = (
        "## Context\n"
        "The change is similar to lib/reviewer/static_scan.py pattern.\n"  # read-ref only
    )
    findings = _run(meta, body)
    # lib/reviewer/static_scan.py appears without a write verb — should NOT flag
    assert not any("lib/reviewer/static_scan.py" in f.evidence for f in findings)


def test_path_in_code_fence_flagged():
    """Path inside a code-fence block → treated as write target even without verb."""
    meta = {"write_set": ["lib/bar.py"]}
    body = (
        "## Context\n"
        "```\n"
        "# lib/reviewer/new.py\n"
        "def detect(): pass\n"
        "```\n"
    )
    # code fence paths are flagged if not covered
    findings = _run(meta, body)
    # lib/reviewer/new.py is in code fence AND in source dir AND not in write_set
    assert any("lib/reviewer/new.py" in f.evidence for f in findings)


# ───────────────────────── Gate 3: non-source dirs not flagged ───────────────


def test_path_outside_source_dirs_not_flagged():
    """A path like vendor/external/thing.py is not under a known source dir."""
    meta = {"write_set": ["lib/foo.py"]}
    body = "## Context\nCopy vendor/external/thing.py to local.\n"
    # vendor/ not in _WRITE_SET_SOURCE_PREFIXES → should not flag
    findings = _run(meta, body)
    assert not any("vendor/external/thing.py" in f.evidence for f in findings)


def test_verification_section_paths_not_flagged():
    """Paths in the ## Verification section are read-only commands, not write targets."""
    meta = {"write_set": ["lib/bar.py"]}
    body = (
        "## Context\nEdits lib/bar.py.\n\n"
        "## Verification\n"
        "pytest tests/unit/test_write_set.py -v\n"
    )
    findings = _run(meta, body)
    # tests/unit/test_write_set.py appears only in Verification → must NOT flag
    assert not any("tests/unit/test_write_set.py" in f.evidence for f in findings)
    # lib/bar.py IS in Context with "Edits" verb → covered by write_set (same key) → no flag
    assert findings == []


# ───────────────────────── Integration: scan_task plumbing ───────────────────


def test_scan_task_wires_detector(tmp_path):
    """scan_task() calls detect_write_set_underdeclared and surfaces its findings."""
    (tmp_path / "policy").mkdir()
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    # Minimal catalogue
    catalogue_path = tmp_path / "policy" / "anti-patterns.yaml"
    catalogue_path.write_text(
        "catalogue_version: test\nverdict_thresholds:\n  fail_on_severities: [complete, severe]\n"
        "  concern_on_severities: [partial, narrow, staleness]\n"
    )
    task_path = tmp_path / ".tasks" / "active" / "T-9001-test.md"
    task_path.write_text(
        "---\n"
        "id: T-9001\n"
        "write_set:\n  - lib/bar.py\n"
        "---\n\n"
        "## Context\n\n"
        "Create lib/reviewer/new_module.py with IW-4 logic.\n\n"
        "## Acceptance Criteria\n\n"
        "### Agent\n\n"
        "- [x] Writes lib/reviewer/new_module.py\n\n"
        "## Verification\n\n"
        "pytest tests/unit/ -v\n"
    )
    import yaml
    catalogue = yaml.safe_load(catalogue_path.read_text())
    verdict = ss.scan_task(task_path, catalogue)
    ws_findings = [f for f in verdict.findings if f.pattern_id == "write-set-underdeclared"]
    assert len(ws_findings) >= 1
    assert any("lib/reviewer/new_module.py" in f.evidence for f in ws_findings)
    assert verdict.overall in {"CONCERN", "FAIL"}
