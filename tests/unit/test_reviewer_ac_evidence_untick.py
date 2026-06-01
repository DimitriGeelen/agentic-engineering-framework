"""T-2155 (T-1761 prevention): tests for detect_ac_evidence_untick.

Detector fires when an `### Agent` AC is unticked but the artifact it
names plainly exists with substantive content. The structural fingerprint
of the T-1761 block: an explicit `docs/reports/T-NNNN-*.md` deliverable
shipped, recorded inside its body — yet the AC checkbox stayed `[ ]`,
which the decide flow / completion gate then mechanically refuses.

Six gates (all must hold per AC):
  1. AC sits under `### Agent` subhead
  2. AC is unticked (`- [ ]`)
  3. AC text does NOT start with `[REVIEWER]` (T-1985 owns those)
  4. AC text references a `docs/reports/T-NNNN-*.md` path
  5. Artifact exists with substantive content (Recommendation marker
     OR ≥1500 bytes)
  6. No opt-out marker (`ac-evidence-untick-ok`)
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402


# ───────────────────────── Fixture helpers ─────────────────────────


def _build_repo(
    tmp_path: Path,
    *,
    artifact_body: str | None,
    ac_section: str,
    artifact_name: str = "T-9999-fixture.md",
) -> tuple[str, Path]:
    """Stand up a minimal repo with optional artifact + return (ac_section, task_path)."""
    (tmp_path / "policy").mkdir(parents=True, exist_ok=True)
    (tmp_path / "docs" / "reports").mkdir(parents=True, exist_ok=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True, exist_ok=True)
    if artifact_body is not None:
        (tmp_path / "docs" / "reports" / artifact_name).write_text(artifact_body)
    task = tmp_path / ".tasks" / "active" / "T-9999-fixture.md"
    task.write_text("placeholder")
    return ac_section, task


# Reusable "substantive" artifact body with a Recommendation line.
_GOOD_ARTIFACT = """# T-9999 research

## Findings

Long body etc.

## Recommendation

**Recommendation:** GO

**Rationale:** Because reasons.
"""


# ───────────────────────── (a) Positive ─────────────────────────


def test_positive_agent_unticked_with_existing_artifact(tmp_path):
    """T-1761-shaped: Agent AC unticked, artifact exists with Recommendation line."""
    ac = """### Agent
- [ ] Inception: evaluate naming-convention heuristic; produce go/no-go in research artifact docs/reports/T-9999-fixture.md
"""
    ac_section, task_path = _build_repo(
        tmp_path, artifact_body=_GOOD_ARTIFACT, ac_section=ac
    )
    findings = ss.detect_ac_evidence_untick(ac_section, task_path)
    assert len(findings) == 1
    f = findings[0]
    assert f.pattern_id == "ac-evidence-untick"
    assert f.lie_severity == "partial"
    assert f.ac_index == 1
    assert f.ac_subhead == "Agent"
    assert "T-9999-fixture.md" in f.evidence


# ───────────────────────── (b) Negative — ticked AC ─────────────────────────


def test_negative_when_ac_is_ticked(tmp_path):
    """A ticked AC is in good standing; detector must stay silent."""
    ac = """### Agent
- [x] Inception: produce go/no-go in research artifact docs/reports/T-9999-fixture.md
"""
    ac_section, task_path = _build_repo(
        tmp_path, artifact_body=_GOOD_ARTIFACT, ac_section=ac
    )
    assert ss.detect_ac_evidence_untick(ac_section, task_path) == []


# ───────────────────────── (c) Negative — no artifact path in AC ─────────────────────────


def test_negative_when_ac_text_has_no_artifact_path(tmp_path):
    """No `docs/reports/T-NNNN-*.md` reference → out of scope."""
    ac = """### Agent
- [ ] Ship the classifier with two-tier verb matching.
"""
    # Even if a similarly named artifact exists, the AC text doesn't reference it.
    ac_section, task_path = _build_repo(
        tmp_path, artifact_body=_GOOD_ARTIFACT, ac_section=ac
    )
    assert ss.detect_ac_evidence_untick(ac_section, task_path) == []


# ───────────────────────── (d) Negative — artifact missing ─────────────────────────


def test_negative_when_artifact_does_not_exist(tmp_path):
    """AC promises an artifact that hasn't been written yet → out of scope."""
    ac = """### Agent
- [ ] Produce go/no-go in research artifact docs/reports/T-9999-fixture.md
"""
    ac_section, task_path = _build_repo(
        tmp_path, artifact_body=None, ac_section=ac
    )
    assert ss.detect_ac_evidence_untick(ac_section, task_path) == []


# ───────────────────────── (e) Negative — [REVIEWER] prefix ─────────────────────────


def test_negative_when_ac_has_reviewer_prefix(tmp_path):
    """T-1985 auto-tick owns `[REVIEWER]` ACs — don't double up with CONCERN."""
    ac = """### Agent
- [ ] [REVIEWER] Block-message names both bypass mechanisms — see docs/reports/T-9999-fixture.md
"""
    ac_section, task_path = _build_repo(
        tmp_path, artifact_body=_GOOD_ARTIFACT, ac_section=ac
    )
    assert ss.detect_ac_evidence_untick(ac_section, task_path) == []


# ───────────────────────── (f) Negative — opt-out marker ─────────────────────────


def test_negative_with_opt_out_marker(tmp_path):
    """Author can opt out with `ac-evidence-untick-ok` for in-flight reviews."""
    ac = """### Agent
- [ ] Produce go/no-go in research artifact docs/reports/T-9999-fixture.md (ac-evidence-untick-ok — human review in flight)
"""
    ac_section, task_path = _build_repo(
        tmp_path, artifact_body=_GOOD_ARTIFACT, ac_section=ac
    )
    assert ss.detect_ac_evidence_untick(ac_section, task_path) == []


# ───────────────────────── (g) Negative — Human-section AC ─────────────────────────


def test_negative_for_human_section_ac(tmp_path):
    """Human ACs are off-scope — they verify by hand, not via checkbox sync."""
    ac = """### Agent
- [x] Implementation complete.

### Human
- [ ] [REVIEW] Page renders correctly — see docs/reports/T-9999-fixture.md
"""
    ac_section, task_path = _build_repo(
        tmp_path, artifact_body=_GOOD_ARTIFACT, ac_section=ac
    )
    assert ss.detect_ac_evidence_untick(ac_section, task_path) == []


# ───────────────────────── (h) Size-substantive path ─────────────────────────


def test_positive_substantive_size_without_recommendation_marker(tmp_path):
    """Artifact has no Recommendation line/heading but is ≥1500 bytes → substantive proxy."""
    big_body = "# T-9999 research\n\n" + ("text body line.\n" * 200)
    assert len(big_body) > 1500
    ac = """### Agent
- [ ] Produce findings in research artifact docs/reports/T-9999-fixture.md
"""
    ac_section, task_path = _build_repo(
        tmp_path, artifact_body=big_body, ac_section=ac
    )
    findings = ss.detect_ac_evidence_untick(ac_section, task_path)
    assert len(findings) == 1
    assert "size=" in findings[0].evidence


# ───────────────────────── (i) Skeleton artifact stays silent ─────────────────────────


def test_negative_when_artifact_is_skeleton(tmp_path):
    """Artifact exists but is a placeholder shell — detector stays silent."""
    skeleton = "# T-9999\n\nTBD.\n"
    ac = """### Agent
- [ ] Produce go/no-go in research artifact docs/reports/T-9999-fixture.md
"""
    ac_section, task_path = _build_repo(
        tmp_path, artifact_body=skeleton, ac_section=ac
    )
    assert ss.detect_ac_evidence_untick(ac_section, task_path) == []


# ───────────────────────── (j) Multiple Agent ACs ─────────────────────────


def test_two_acs_only_unticked_one_fires(tmp_path):
    """Mixed batch: ticked AC silent, unticked AC fires once."""
    ac = """### Agent
- [x] Wrote the classifier in agents/audit/orchestrator-mcp-scan.sh.
- [ ] Produce go/no-go in research artifact docs/reports/T-9999-fixture.md
"""
    ac_section, task_path = _build_repo(
        tmp_path, artifact_body=_GOOD_ARTIFACT, ac_section=ac
    )
    findings = ss.detect_ac_evidence_untick(ac_section, task_path)
    assert len(findings) == 1
    assert findings[0].ac_index == 2
