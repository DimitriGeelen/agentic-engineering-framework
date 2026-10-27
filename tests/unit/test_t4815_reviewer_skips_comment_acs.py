"""T-4815: scan_task must not treat ACs inside `<!-- … -->` as real ACs.

Field report (ring20 be.37, their T-2544; AEF T-4773/T-4783): the default
template's `### Human` comment carries a worked `- [ ] [REVIEWER] Block message
names both bypass mechanisms` example. T-2156 stripped comments only inside
`_parse_agent_acs` (the auto-tick path); every detector `scan_task` runs over
`ac_section` still saw the example and `reviewer-prose-mismatch` fired on it.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402

TEMPLATE_HUMAN_COMMENT = """<!-- Criteria requiring human verification (UI/UX, subjective quality).

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel

     [REVIEWER] example (static-scan-verifiable):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; reads clearly and names both mechanisms
         **If not:** Inspect hook block-message string
-->"""


def _write_task(tmp_path: Path, human_body: str) -> Path:
    task = tmp_path / "T-9999-fixture.md"
    task.write_text(
        "---\nid: T-9999\nname: fixture\nworkflow_type: build\nstatus: started-work\n---\n\n"
        "# T-9999: fixture\n\n"
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [ ] Real agent AC one\n\n"
        "### Human\n"
        f"{human_body}\n\n"
        "## Verification\n\n"
        "python3 -c 'import sys'\n"
    )
    return task


def _human_findings(verdict) -> list:
    return [
        f for f in verdict.findings
        if (getattr(f, "ac_subhead", "") or "").lower() == "human"
    ]


def test_commented_template_example_is_not_an_ac(tmp_path):
    task = _write_task(tmp_path, TEMPLATE_HUMAN_COMMENT)
    verdict = ss.scan_task(task, {})
    ids = [f.pattern_id for f in verdict.findings]
    assert "reviewer-prose-mismatch" not in ids, ids
    assert _human_findings(verdict) == [], _human_findings(verdict)


def test_real_acs_around_comment_keep_their_indexes(tmp_path):
    human = (
        "- [ ] [REVIEWER] First real AC\n"
        "  **Expected:** layout reads clearly\n"
        f"{TEMPLATE_HUMAN_COMMENT}\n"
        "- [ ] [REVIEWER] Second real AC\n"
        "  **Expected:** tone feels right\n"
    )
    task = _write_task(tmp_path, human)
    verdict = ss.scan_task(task, {})
    prose = [f for f in verdict.findings if f.pattern_id == "reviewer-prose-mismatch"]
    assert sorted(f.ac_index for f in prose) == [1, 2], [
        (f.ac_index, f.ac_text) for f in prose
    ]
    assert all("Block message" not in (f.ac_text or "") for f in prose)


def test_scan_ac_section_blanks_comments_preserving_lines():
    text = "a\n<!-- x\n- [ ] y\n-->\nb"
    out = ss._blank_structural_html_comments(text)
    assert "- [ ]" not in out
    assert out.count("\n") == text.count("\n")


def test_marker_only_comment_is_kept():
    """Opt-out markers live in comments; a comment with no AC/heading survives."""
    text = "- [ ] x\n  <!-- review-link-homework-ok: documents it -->\n"
    assert ss._blank_structural_html_comments(text) == text


def test_commented_heading_is_blanked():
    text = "<!-- ### Human -->\n- [ ] y"
    assert "### Human" not in ss._blank_structural_html_comments(text)
