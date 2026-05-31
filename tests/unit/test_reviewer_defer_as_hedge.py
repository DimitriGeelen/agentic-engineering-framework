"""T-2145 (T-2144 leg B): tests for detect_defer_as_hedge.

Detector fires when an inception task is filed with `Recommendation: DEFER`
despite its research artifact carrying complete evidence. The structural
fingerprint of T-2143's hedge: 5-Whys + Dialogue Log + Rationale-substantive,
but Recommendation field punts to operator.

Five gates (all must hold):
  1. workflow_type: inception
  2. Recommendation: DEFER (excludes "DEFER (historical)" markers)
  3. Artifact path present
  4. Artifact exists with ≥2 evidence indicators
  5. Rationale block >300 chars

Note: AC spec called for ≥1 indicator; T-2145 corpus walk raised to ≥2
to suppress sovereignty-pending DEFERs that have Dialogue Log alone.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402


def _build_repo(tmp_path: Path, artifact_body: str, task_body: str) -> Path:
    """Stand up a minimal repo with one artifact + one task. Return task_path."""
    (tmp_path / "policy").mkdir(parents=True, exist_ok=True)
    (tmp_path / "docs" / "reports").mkdir(parents=True, exist_ok=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True, exist_ok=True)
    artifact = tmp_path / "docs" / "reports" / "T-9999-fixture.md"
    artifact.write_text(artifact_body)
    task = tmp_path / ".tasks" / "completed" / "T-9999-fixture.md"
    task.write_text(task_body)
    return task


# ───────────────────────── Positive case ─────────────────────────


def test_fires_on_full_evidence_defer(tmp_path):
    """AC #4 case (a): DEFER + 2 evidence indicators + long rationale → CONCERN."""
    artifact = """# T-9999 RCA
## 5-Whys
1. Why?
## Dialogue Log
Q: A?
"""
    task = """---
workflow_type: inception
---

# T-9999

## Recommendation

**Recommendation:** DEFER — pending operator pick.

**Rationale:** """ + "x" * 500 + """ See docs/reports/T-9999-fixture.md.
"""
    task_path = _build_repo(tmp_path, artifact, task)
    meta = {"workflow_type": "inception"}
    body = task_path.read_text().split("---\n", 2)[2]
    findings = ss.detect_defer_as_hedge(meta, body, task_path)
    assert len(findings) == 1
    assert findings[0].pattern_id == "defer-as-hedge"
    assert "5-Whys" in findings[0].evidence
    assert "Dialogue Log" in findings[0].evidence


def test_fires_with_candidate_matrix(tmp_path):
    """5-Whys + ≥3 candidate matrix rows is enough (2 indicators)."""
    artifact = """# T-9999

## 5-Whys
1. Why?

## Candidate Matrix

| Candidate | Effort | Coverage |
|-----------|--------|----------|
| A | 1 | low |
| B | 2 | mid |
| C | 5 | high |
"""
    task = """---
workflow_type: inception
---

# T-9999

## Recommendation

**Recommendation:** DEFER

**Rationale:** """ + "x" * 500 + """ See docs/reports/T-9999-fixture.md.
"""
    task_path = _build_repo(tmp_path, artifact, task)
    body = task_path.read_text().split("---\n", 2)[2]
    findings = ss.detect_defer_as_hedge({"workflow_type": "inception"}, body, task_path)
    assert len(findings) == 1
    assert "candidate matrix" in findings[0].evidence


# ───────────────────────── Negative cases ─────────────────────────


def test_silent_on_defer_with_no_evidence(tmp_path):
    """AC #4 case (b): DEFER + only one indicator → NOT triggered (legitimate)."""
    artifact = """# T-9999
## Dialogue Log
Q: A?
"""
    task = """---
workflow_type: inception
---

# T-9999

## Recommendation

**Recommendation:** DEFER

**Rationale:** """ + "x" * 500 + """ See docs/reports/T-9999-fixture.md.
"""
    task_path = _build_repo(tmp_path, artifact, task)
    body = task_path.read_text().split("---\n", 2)[2]
    findings = ss.detect_defer_as_hedge({"workflow_type": "inception"}, body, task_path)
    assert len(findings) == 0


def test_silent_on_go_with_full_evidence(tmp_path):
    """AC #4 case (c): GO + full evidence → NOT triggered."""
    artifact = """# T-9999
## 5-Whys
1. Why?
## Dialogue Log
Q: A?
"""
    task = """---
workflow_type: inception
---

# T-9999

## Recommendation

**Recommendation:** GO — Candidate D.

**Rationale:** """ + "x" * 500 + """ See docs/reports/T-9999-fixture.md.
"""
    task_path = _build_repo(tmp_path, artifact, task)
    body = task_path.read_text().split("---\n", 2)[2]
    findings = ss.detect_defer_as_hedge({"workflow_type": "inception"}, body, task_path)
    assert len(findings) == 0


def test_silent_on_nogo_with_full_evidence(tmp_path):
    """AC #4 case (d): NO-GO + full evidence → NOT triggered."""
    artifact = """# T-9999
## 5-Whys
1. Why?
## Dialogue Log
Q: A?
"""
    task = """---
workflow_type: inception
---

# T-9999

## Recommendation

**Recommendation:** NO-GO — Candidate A rejected.

**Rationale:** """ + "x" * 500 + """ See docs/reports/T-9999-fixture.md.
"""
    task_path = _build_repo(tmp_path, artifact, task)
    body = task_path.read_text().split("---\n", 2)[2]
    findings = ss.detect_defer_as_hedge({"workflow_type": "inception"}, body, task_path)
    assert len(findings) == 0


def test_silent_on_non_inception(tmp_path):
    """AC #4 case (e): workflow_type != inception → NOT triggered."""
    artifact = """# T-9999
## 5-Whys
1. Why?
## Dialogue Log
Q: A?
"""
    task = """---
workflow_type: build
---

# T-9999

## Recommendation

**Recommendation:** DEFER

**Rationale:** """ + "x" * 500 + """ See docs/reports/T-9999-fixture.md.
"""
    task_path = _build_repo(tmp_path, artifact, task)
    body = task_path.read_text().split("---\n", 2)[2]
    findings = ss.detect_defer_as_hedge({"workflow_type": "build"}, body, task_path)
    assert len(findings) == 0


def test_silent_on_defer_historical_marker(tmp_path):
    """`DEFER (historical — superseded)` is the legitimate revisit-trigger
    shape, not a hedge."""
    artifact = """# T-9999
## 5-Whys
1. Why?
## Dialogue Log
Q: A?
"""
    task = """---
workflow_type: inception
---

# T-9999

## Recommendation

**Recommendation:** DEFER (historical — superseded by 2026-05-31 re-evaluation)

**Rationale:** """ + "x" * 500 + """ See docs/reports/T-9999-fixture.md.
"""
    task_path = _build_repo(tmp_path, artifact, task)
    body = task_path.read_text().split("---\n", 2)[2]
    findings = ss.detect_defer_as_hedge({"workflow_type": "inception"}, body, task_path)
    assert len(findings) == 0


def test_silent_on_short_rationale(tmp_path):
    """Rationale ≤300 chars → not substantive → not the hedge class."""
    artifact = """# T-9999
## 5-Whys
1. Why?
## Dialogue Log
Q: A?
"""
    task = """---
workflow_type: inception
---

# T-9999

## Recommendation

**Recommendation:** DEFER

**Rationale:** short reason. See docs/reports/T-9999-fixture.md.
"""
    task_path = _build_repo(tmp_path, artifact, task)
    body = task_path.read_text().split("---\n", 2)[2]
    findings = ss.detect_defer_as_hedge({"workflow_type": "inception"}, body, task_path)
    assert len(findings) == 0


def test_silent_on_missing_artifact(tmp_path):
    """Artifact path present but file does not exist on disk → silent."""
    (tmp_path / "policy").mkdir(parents=True, exist_ok=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True, exist_ok=True)
    task_path = tmp_path / ".tasks" / "completed" / "T-9999.md"
    task_path.write_text("""---
workflow_type: inception
---

# T-9999

## Recommendation

**Recommendation:** DEFER

**Rationale:** """ + "x" * 500 + """ See docs/reports/T-MISSING.md.
""")
    body = task_path.read_text().split("---\n", 2)[2]
    findings = ss.detect_defer_as_hedge({"workflow_type": "inception"}, body, task_path)
    assert len(findings) == 0


def test_silent_on_no_artifact_path(tmp_path):
    """No artifact path in Recommendation section → silent."""
    (tmp_path / "policy").mkdir(parents=True, exist_ok=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True, exist_ok=True)
    task_path = tmp_path / ".tasks" / "completed" / "T-9999.md"
    task_path.write_text("""---
workflow_type: inception
---

# T-9999

## Recommendation

**Recommendation:** DEFER

**Rationale:** """ + "x" * 500 + """ no artifact path here.
""")
    body = task_path.read_text().split("---\n", 2)[2]
    findings = ss.detect_defer_as_hedge({"workflow_type": "inception"}, body, task_path)
    assert len(findings) == 0


def test_silent_on_missing_recommendation_section():
    """No `## Recommendation` section at all → silent."""
    body = "# T-9999\n\nSome other content."
    findings = ss.detect_defer_as_hedge({"workflow_type": "inception"}, body, Path("/tmp/nothing"))
    assert len(findings) == 0


def test_silent_on_empty_meta():
    """Missing meta or wrong workflow_type → silent."""
    body = """## Recommendation

**Recommendation:** DEFER

**Rationale:** """ + "x" * 500 + """ See docs/reports/T-X.md.
"""
    assert ss.detect_defer_as_hedge(None, body, Path("/tmp/nothing")) == []
    assert ss.detect_defer_as_hedge({}, body, Path("/tmp/nothing")) == []


# ───────────────────────── Integration into scan_task ─────────────────────────


def test_integrated_in_scan_task(tmp_path):
    """Detector is wired into scan_task pipeline."""
    artifact_dir = tmp_path / "docs" / "reports"
    artifact_dir.mkdir(parents=True)
    (artifact_dir / "T-9999-test.md").write_text("""## 5-Whys
1. Why?

## Dialogue Log
Q: A?
""")
    (tmp_path / "policy").mkdir()
    (tmp_path / "policy" / "anti-patterns.yaml").write_text("# stub\n")
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    task_path = tmp_path / ".tasks" / "completed" / "T-9999-test.md"
    task_path.write_text("""---
id: T-9999
name: defer-fixture
status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-31T00:00:00Z
last_update: 2026-05-31T00:00:00Z
date_finished: null
---

# T-9999

## Acceptance Criteria

### Agent
- [x] Did the work

## Recommendation

**Recommendation:** DEFER

**Rationale:** """ + "x" * 500 + """ See docs/reports/T-9999-test.md.
""")
    catalogue = {
        "verdict_thresholds": {
            "fail_on_severities": ["complete", "severe"],
            "concern_on_severities": ["partial", "narrow", "staleness"],
        },
        "catalogue_version": "test",
    }
    verdict = ss.scan_task(task_path, catalogue)
    ids = [f.pattern_id for f in verdict.findings]
    assert "defer-as-hedge" in ids
