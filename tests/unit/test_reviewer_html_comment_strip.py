"""T-2156 (OBS-047): tests for HTML-comment strip in `_parse_agent_acs`.

`<!-- … -->` blocks in the AC section contain documentation examples
(the default.md template's `### Human` worked example carries a
`- [ ] [REVIEWER] Block message names both bypass mechanisms` bullet).
Without HTML-comment awareness, the parser counts those bullets as live
Agent ACs and the T-1985 auto-tick subsystem flips them to `[x]` on PASS.

L-414 cross-reference: the sed-range strip in agents/task-create has
known same-line / multi-line interaction pitfalls; the Python `re.DOTALL`
strip used here is unaffected by that class. Test (d) covers the mixed
shape explicitly.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib.reviewer import static_scan as ss  # noqa: E402


# ───────────────────────── _strip_html_comments unit ─────────────────────────


def test_strip_single_line_html_comment():
    """Single-line `<!-- ... -->` removed verbatim."""
    text = "before <!-- inline --> after"
    assert ss._strip_html_comments(text) == "before  after"


def test_strip_multi_line_html_comment():
    """Multi-line `<!-- ... \n ... -->` removed via DOTALL."""
    text = "before\n<!-- line1\n line2\n line3 -->\nafter"
    out = ss._strip_html_comments(text)
    assert "line1" not in out and "line2" not in out
    assert "before" in out and "after" in out


def test_strip_l414_cross_shape():
    """L-414 mixed shape: single-line comment followed by multi-line block.

    sed range would mis-handle this (its delete-mode latches on the first
    `<!--` and doesn't release until the next `-->`). Python `re.DOTALL`
    correctly closes each `<!--…-->` non-greedily.
    """
    text = "real-1\n<!-- single -->\nreal-2\n<!-- multi\n  bullet inside\n-->\nreal-3"
    out = ss._strip_html_comments(text)
    assert "real-1" in out and "real-2" in out and "real-3" in out
    assert "single" not in out and "multi" not in out
    assert "bullet inside" not in out


def test_strip_preserves_text_without_comments():
    """No-op when input contains no `<!--`."""
    text = "### Agent\n- [ ] AC1\n- [x] AC2"
    assert ss._strip_html_comments(text) == text


# ───────────────────────── _parse_agent_acs integration ─────────────────────────


def test_parse_skips_bullet_inside_single_line_comment():
    """A bullet inside `<!-- ... -->` on one line is not parsed as an AC."""
    section = """### Agent
- [ ] Real AC
<!-- - [ ] [REVIEWER] commented example -->
"""
    acs = ss._parse_agent_acs(section)
    assert len(acs) == 1
    assert "Real AC" in acs[0].ac_text


def test_parse_skips_bullets_inside_multi_line_comment():
    """The default.md template's multi-line Human-example block: bullets must not count."""
    section = """### Agent
- [ ] Real AC #1
- [x] Real AC #2

<!-- Multi-line documentation block
     - [ ] [REVIEW] Example human AC
     - [ ] [REVIEWER] Example reviewer AC
-->
"""
    acs = ss._parse_agent_acs(section)
    assert len(acs) == 2
    assert acs[0].ac_text.startswith("Real AC #1")
    assert acs[1].ac_text.startswith("Real AC #2")
    # neither REVIEWER nor REVIEW example survived
    for ac in acs:
        assert "REVIEWER" not in ac.ac_text
        assert "REVIEW]" not in ac.ac_text


def test_parse_handles_missing_human_subhead():
    """L-449 anti-pattern: author edits in-place but drops ### Human.

    Even without the closing subhead, commented bullets must not be
    parsed under ### Agent (this is the exact T-2155 FP).
    """
    section = """### Agent
- [ ] Real AC #1
- [ ] Real AC #2
<!-- Criteria requiring human verification ...
     - [ ] [REVIEWER] Block message names both bypass mechanisms
     ...
-->
"""
    acs = ss._parse_agent_acs(section)
    assert len(acs) == 2
    assert all("REVIEWER" not in ac.ac_text for ac in acs)


# ───────────────────────── T-2155 real-file regression ─────────────────────────


def test_parse_t2155_returns_six_acs():
    """T-2155's actual file: 6 real Agent ACs, no FP from template-comment bullets."""
    repo_root = Path(__file__).resolve().parent.parent.parent
    tf = repo_root / ".tasks" / "completed" / "T-2155-reviewer-detector--agent-ac-body-evidenc.md"
    if not tf.exists():
        # Skip if the closed task moved or got renamed
        return
    _, body = ss.parse_task_file(tf)
    ac_section = ss.extract_section(body, "Acceptance Criteria") or ""
    acs = ss._parse_agent_acs(ac_section)
    assert len(acs) == 6, (
        f"Expected 6 Agent ACs (FP-resolved), got {len(acs)}: "
        f"{[ac.ac_text[:50] for ac in acs]}"
    )
    # Confirm none of them are the template-comment line
    for ac in acs:
        assert "Block message names" not in ac.ac_text
        assert "Dashboard renders correctly" not in ac.ac_text


# ───────────────────────── Negative — real bullet still counts ─────────────────────────


def test_real_unticked_ac_still_parses():
    """Sanity: nothing about the comment-strip removes legitimate ACs."""
    section = """### Agent
- [ ] Implement the thing
- [x] Test the thing

### Human
- [ ] [REVIEW] Look at the thing
"""
    acs = ss._parse_agent_acs(section)
    assert len(acs) == 2
    assert acs[0].ticked is False
    assert acs[1].ticked is True
