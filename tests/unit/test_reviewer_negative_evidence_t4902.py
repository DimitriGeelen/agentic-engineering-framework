"""T-4902 (ring20-dashboard pilot): a reviewer PASS never ticks a criterion over its own
recorded negative evidence, and a delegation-converted criterion that names no scanned
check is never ticked by a static PASS (T-4778 behaviour, pinned for this case)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402

CATALOGUE_PATH = ROOT / "policy" / "anti-patterns.yaml"


@pytest.fixture
def catalogue() -> dict:
    return ss.load_catalogue(CATALOGUE_PATH)


def _task(tmp_path: Path, name: str, ac_block: str) -> Path:
    text = "\n".join([
        "---", "id: T-9900", f"name: {name}", "status: started-work", "workflow_type: build", "---",
        "", "# T-9900", "", "## Acceptance Criteria", "", *ac_block.splitlines(), "",
        "## Verification", "", "",
    ])
    p = tmp_path / ".tasks" / "active" / f"T-9900-{name}.md"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)
    return p


def _ticks(tmp_path: Path, p: Path, catalogue: dict):
    stream = tmp_path / ".context" / "working" / "feedback-stream.yaml"
    stream.parent.mkdir(parents=True, exist_ok=True)
    verdict = ss.scan_task(p, catalogue)
    ticked, _ = ss._compute_auto_ticks(p, "T-9900", verdict, [], stream)
    return verdict, ticked


def test_delegated_criterion_naming_no_check_is_not_ticked(tmp_path, catalogue):
    """ring20-dashboard's T-510 shape after `fw task delegate`: no scanned check named."""
    p = _task(tmp_path, "delegated", "\n".join([
        "### Agent",
        "- [ ] [REVIEWER] Add client on the dashboard succeeds when the secret is configured",
        "  **Expected:** toast 'Client X added', QR modal",
    ]))
    verdict, ticked = _ticks(tmp_path, p, catalogue)
    assert verdict.overall == "PASS"
    assert ticked == []


def test_negative_evidence_blocks_the_tick(tmp_path, catalogue):
    """ring20-dashboard's T-372 shape: the criterion names a check AND its own evidence is negative."""
    p = _task(tmp_path, "negative", "\n".join([
        "### Agent",
        "- [ ] [REVIEWER] endpoints respond — no findings on tautology",
        "  **Evidence:** NEGATIVE FINDING: endpoints return 404",
    ]))
    verdict, ticked = _ticks(tmp_path, p, catalogue)
    assert ticked == []
    assert any(f.pattern_id == "ac-negative-evidence" and f.ac_index == 1 for f in verdict.findings)
    assert verdict.overall == "CONCERN"


@pytest.mark.parametrize("evidence", [
    "  **Evidence:** live check FAILS: 404 on /api/x",
    "  - Evidence: smoke test FAILED at step 2",
    "  NEGATIVE RESULT on the live host",
])
def test_other_negative_forms_block_the_tick(tmp_path, catalogue, evidence):
    p = _task(tmp_path, "neg2", "\n".join([
        "### Agent",
        "- [ ] [REVIEWER] endpoints respond — no findings on tautology",
        evidence,
    ]))
    _, ticked = _ticks(tmp_path, p, catalogue)
    assert ticked == []


def test_same_criterion_without_negative_evidence_still_ticks(tmp_path, catalogue):
    p = _task(tmp_path, "clean", "\n".join([
        "### Agent",
        "- [ ] [REVIEWER] endpoints respond — no findings on tautology",
        "  **Evidence:** WORKS on the live host (200 on /api/x)",
    ]))
    verdict, ticked = _ticks(tmp_path, p, catalogue)
    assert verdict.overall == "PASS"
    assert len(ticked) == 1


def test_negative_evidence_on_another_criterion_does_not_block_this_one(tmp_path, catalogue):
    p = _task(tmp_path, "two", "\n".join([
        "### Agent",
        "- [ ] [REVIEWER] first — no findings on tautology",
        "  **Evidence:** NEGATIVE FINDING: broken",
        "- [ ] [REVIEWER] second — no findings on empty-body",
        "  **Evidence:** WORKS",
    ]))
    verdict, ticked = _ticks(tmp_path, p, catalogue)
    flagged = {f.ac_index for f in verdict.findings if f.pattern_id == "ac-negative-evidence"}
    assert flagged == {1}


def test_verdict_block_states_what_pass_means():
    v = ss.Verdict(task_id="T-9900", scan_id="s", timestamp="t", catalogue_version="c",
                   overall="PASS", needs_human=False, findings=[])
    md = ss.render_verdict_md(v)
    assert "PASS means no anti-pattern was found, not that the criteria hold" in md
