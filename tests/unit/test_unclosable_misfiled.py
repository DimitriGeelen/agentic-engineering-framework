#!/usr/bin/env python3
"""T-3449 — owner:human tasks with no real Human criteria and all Agent
criteria ticked have no route to closure.

Fixtures cover the four AC-mandated cases plus two regression pins for real
parse bugs found while building the predicate against the live corpus:

  * the template-comment false positive (the exact parse that made two
    ad-hoc measurements of this class disagree during discovery)
  * a real Human criterion hidden behind a suffix-qualified heading
    (`### Human (Slice 1)`) — live on T-1062/T-1718
  * a real Human criterion hidden behind an intervening `## ` heading
    (the T-3029/T-2420 class) — live on T-2200/T-2202 before this fix
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib.delegation import frontmatter  # noqa: E402
from lib.unclosable_misfiled import (  # noqa: E402
    agent_criteria,
    count_human_acs_total,
    is_unclosable_misfiled,
    scan_active,
)

FM = """---
id: T-9999
name: "fixture"
status: started-work
workflow_type: build
owner: {owner}
created: 2026-01-01T00:00:00Z
last_update: 2026-01-01T00:00:00Z
---

"""

TEMPLATE_HUMAN_COMMENT = """### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel
-->
"""


def task(owner, body):
    return FM.format(owner=owner) + body


# ── AC-mandated fixture 1: template-comment false positive ───────────────────


def test_template_comment_is_not_a_real_human_criterion():
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [x] First thing done\n"
        "- [x] Second thing done\n\n"
        + TEMPLATE_HUMAN_COMMENT
        + "\n## Verification\n"
    )
    text = task("human", body)
    meta = frontmatter(text)
    assert count_human_acs_total(text) == 0
    assert is_unclosable_misfiled(meta, text) is True


# ── AC-mandated fixture 2: one real Human criterion — NOT in the class ────────


def test_one_real_human_criterion_excludes_the_task():
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [x] First thing done\n\n"
        "### Human\n"
        "- [ ] [REVIEW] Layout reads clean\n"
        "  **Steps:** open the page\n"
        "  **Expected:** looks right\n"
        "  **If not:** screenshot it\n\n"
        "## Verification\n"
    )
    text = task("human", body)
    meta = frontmatter(text)
    assert count_human_acs_total(text) == 1
    assert is_unclosable_misfiled(meta, text) is False


def test_one_real_ticked_human_criterion_also_excludes_the_task():
    # A ticked-but-present Human AC is the CTL-031 "stuck partial-complete"
    # shape, not this class — the predicate counts total lines, not open ones.
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [x] First thing done\n\n"
        "### Human\n"
        "- [x] [REVIEW] Layout reads clean\n\n"
        "## Verification\n"
    )
    text = task("human", body)
    meta = frontmatter(text)
    assert count_human_acs_total(text) == 1
    assert is_unclosable_misfiled(meta, text) is False


# ── AC-mandated fixture 3: agent-owned, all ticked — NOT in the class ─────────


def test_agent_owned_all_ticked_excludes_the_task():
    # This is the ordinary CTL-029 "completable but not closed" case — no
    # sovereignty gate blocks it, so it is not a member of THIS class.
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [x] First thing done\n"
        "- [x] Second thing done\n\n"
        + TEMPLATE_HUMAN_COMMENT
        + "\n## Verification\n"
    )
    text = task("agent", body)
    meta = frontmatter(text)
    assert is_unclosable_misfiled(meta, text) is False


# ── AC-mandated fixture 4: human-owned, unticked Agent criteria ───────────────


def test_human_owned_unticked_agent_ac_excludes_the_task():
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [x] First thing done\n"
        "- [ ] Second thing NOT done\n\n"
        + TEMPLATE_HUMAN_COMMENT
        + "\n## Verification\n"
    )
    text = task("human", body)
    meta = frontmatter(text)
    assert is_unclosable_misfiled(meta, text) is False


# ── regression: no ### Agent split at all ─────────────────────────────────────


def test_no_agent_split_excludes_the_task():
    body = (
        "## Acceptance Criteria\n\n"
        "- [x] Flat unheaded criterion, ticked\n\n"
        + TEMPLATE_HUMAN_COMMENT
        + "\n## Verification\n"
    )
    text = task("human", body)
    meta = frontmatter(text)
    assert agent_criteria(text) == []
    assert is_unclosable_misfiled(meta, text) is False


# ── regression pin: suffix-qualified Human heading (live: T-1062, T-1718) ────


def test_suffix_qualified_human_heading_with_real_criterion_is_not_missed():
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent (Slice 1)\n"
        "- [x] Mechanical half done\n\n"
        "### Human (Slice 1)\n"
        "- [ ] [REVIEW] Visual render looks right\n"
        "  **Steps:** look at it\n"
        "  **Expected:** renders correctly\n"
        "  **If not:** note the glitch\n\n"
        "## Verification\n"
    )
    text = task("human", body)
    meta = frontmatter(text)
    assert count_human_acs_total(text) == 1
    assert is_unclosable_misfiled(meta, text) is False


def test_suffix_qualified_human_heading_template_comment_still_zero():
    # The suffix-tolerant heading match must not start counting comment-only
    # suffixed sections either — same T-1581 comment strip applies.
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent (Slice 1)\n"
        "- [x] Mechanical half done\n\n"
        "### Human (Slice 1)\n"
        "<!-- placeholder, nothing real here yet\n"
        "  - [ ] [REVIEW] example only\n"
        "-->\n\n"
        "## Verification\n"
    )
    text = task("human", body)
    meta = frontmatter(text)
    assert count_human_acs_total(text) == 0
    assert is_unclosable_misfiled(meta, text) is True


# ── regression pin: intervening ## heading before ### Human (T-3029 class) ───


def test_intervening_h2_heading_before_human_is_not_missed():
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [x] Mechanical done\n\n"
        "## Status: COMPLETED 2026-06-09\n\n"
        "### Human\n"
        "- [ ] [REVIEW] Real criterion hidden behind an intervening H2\n"
        "  **Steps:** verify it\n"
        "  **Expected:** it works\n"
        "  **If not:** note the gap\n\n"
        "## Verification\n"
    )
    text = task("human", body)
    meta = frontmatter(text)
    # lib.delegation.parse_criteria (AC-section-bounded) would report zero
    # Human criteria here — count_human_acs_total (whole-document) must not.
    assert count_human_acs_total(text) == 1
    assert is_unclosable_misfiled(meta, text) is False


# ── scan_active: end-to-end over a small fixture corpus ──────────────────────


def test_scan_active_over_fixture_corpus(tmp_path):
    active = tmp_path / ".tasks" / "active"
    active.mkdir(parents=True)

    member_body = (
        "## Acceptance Criteria\n\n### Agent\n- [x] Done\n\n"
        + TEMPLATE_HUMAN_COMMENT + "\n## Verification\n"
    )
    (active / "T-0001-member.md").write_text(
        FM.format(owner="human").replace("T-9999", "T-0001") + member_body
    )

    non_member_body = (
        "## Acceptance Criteria\n\n### Agent\n- [x] Done\n\n"
        "### Human\n- [ ] [REVIEW] Real one\n\n## Verification\n"
    )
    (active / "T-0002-nonmember.md").write_text(
        FM.format(owner="human").replace("T-9999", "T-0002") + non_member_body
    )

    members = scan_active(tmp_path)
    ids = [m.task_id for m in members]
    assert ids == ["T-0001"]
    assert members[0].agent_ac_count == 1
