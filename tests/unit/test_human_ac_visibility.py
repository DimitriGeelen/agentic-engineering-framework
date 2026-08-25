"""T-3139 — the review-queue predicate could not see Human ACs that exist.

`count_unchecked_human_acs` is the single predicate behind BOTH `/approvals`
and `fw review-queue`. Three live active tasks carried an unchecked `[REVIEW]`
AC that it returned 0 for, so the operator was never asked:

    T-1808  a SECOND `### Human` heading — `re.search` only ever found the first
    T-2200  `## Status: COMPLETED` between `## Acceptance Criteria` and `### Human`
    T-2202  same shape
    T-2877  `## Measured Behaviour` in the same position (completed, found by the sweep)

The failure has no red state. An empty queue is also what a healthy queue looks
like, so a predicate that under-reports is indistinguishable from a day with
nothing to review. That is why this file exists at all: the fix repairs today's
four, the census below is what notices tomorrow's.

Worth recording that consolidation is part of the story. The predicate was
centralised precisely so the web and CLI surfaces could not drift — and it
worked. Both agreed, and on these files both were wrong together. Consolidation
buys consistency and spends the cross-check.

FIXTURES ONLY (L-599) for every behavioural assertion. The four live task ids
above are the origin record and appear in no assertion — fixing the predicate is
expected to change them, so pinning to them would make this a report about the
corpus. The one corpus-reading test asserts AGREEMENT between two independent
scans, never a count, so it survives the corpus moving.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from web.shared import count_unchecked_human_acs  # noqa: E402


# ── AC1: every `### Human` block, not just the first ────────────────────────

def test_second_human_block_is_counted():
    body = (
        "## Acceptance Criteria\n\n"
        "### Human\n- [x] already done\n\n"
        "### Human\n- [ ] NOT done\n"
    )
    assert count_unchecked_human_acs(body) == 1


def test_both_human_blocks_contribute():
    body = (
        "## Acceptance Criteria\n\n"
        "### Human\n- [ ] one\n\n"
        "### Human\n- [ ] two\n"
    )
    assert count_unchecked_human_acs(body) == 2


# ── AC2: an intervening `## ` heading must not truncate the scope ───────────

def test_heading_between_ac_and_human_does_not_hide_it():
    body = (
        "## Acceptance Criteria\n\n### Agent\n- [x] a\n\n"
        "## Status: COMPLETED 2026-06-09\n\nsome prose\n\n"
        "### Human\n- [ ] [REVIEW] verify on the target host\n"
    )
    assert count_unchecked_human_acs(body) == 1


def test_human_block_outside_ac_section_entirely():
    body = "## Measured Behaviour\n\n### Human\n- [ ] [REVIEW] judgement call\n"
    assert count_unchecked_human_acs(body) == 1


# ── AC3: comments must not shadow, and must not swallow ─────────────────────

def test_commented_human_block_does_not_shadow_the_real_one():
    body = (
        "## Acceptance Criteria\n\n"
        "<!--\n### Human\n- [ ] template placeholder\n-->\n\n"
        "### Human\n- [ ] REAL\n"
    )
    assert count_unchecked_human_acs(body) == 1


def test_unbalanced_comment_markers_do_not_swallow_a_real_ac():
    # The T-1545 shape: `<!--` quoted inside backticks while discussing the
    # template, so openers outnumber closers. A naive global
    # `re.sub(r"<!--.*?-->", ...)` pairs the wrong two and eats the AC.
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [x] replaced the line-anchored `grep -v '^<!--'` detector\n\n"
        "### Human\n- [ ] [RUBBER-STAMP] Confirm fix works on a real task\n\n"
        "## Decisions\n\n<!-- Record decisions ONLY when choosing.\n-->\n"
    )
    assert count_unchecked_human_acs(body) == 1


def test_removed_comment_span_leaves_the_next_heading_at_line_start():
    # Regression on the specific defect found while building this fix: dropping
    # a span that contained a newline joined the preceding text onto the
    # following line, so `### Human` was no longer at column 0 and every anchor
    # missed it. Silent, and it looked exactly like "no Human ACs".
    body = "text with `<!--` inline and no closer\n### Human\n- [ ] REAL\n"
    assert count_unchecked_human_acs(body) == 1


# ── Regression guards: pass on BOTH sides by construction ───────────────────
# Not counted as mutation coverage. Their job is to protect the fix from being
# written too loosely — the failure mode of "see more" is "see everything".

def test_guard_empty_body():
    assert count_unchecked_human_acs("") == 0


def test_guard_no_human_section():
    assert count_unchecked_human_acs("## Acceptance Criteria\n\n### Agent\n- [ ] a\n") == 0


def test_guard_all_human_acs_checked():
    assert count_unchecked_human_acs("### Human\n- [x] a\n- [x] b\n") == 0


def test_guard_agent_acs_never_counted():
    body = "## Acceptance Criteria\n\n### Agent\n- [ ] a\n- [ ] b\n\n### Human\n- [x] c\n"
    assert count_unchecked_human_acs(body) == 0


def test_guard_template_comment_placeholders_are_not_counted():
    body = (
        "### Human\n"
        "<!-- Criteria requiring human verification.\n"
        "       - [ ] [REVIEW] Dashboard renders correctly\n"
        "-->\n"
        "- [ ] real one\n"
    )
    assert count_unchecked_human_acs(body) == 1


def test_guard_human_block_ends_at_the_next_heading():
    body = "### Human\n- [ ] mine\n\n## Verification\n\n- [ ] not an AC\n"
    assert count_unchecked_human_acs(body) == 1


# ── AC7: the census. Asserts agreement, never a count. ──────────────────────

def _independent_scan(body: str) -> int:
    """A second, deliberately different implementation of the same question.

    Line-oriented state machine rather than regex-scoped spans, so it shares no
    code path with the predicate. Comment state is entered only by a line whose
    stripped form BEGINS with `<!--` and does not close on the same line — the
    same discriminator the predicate uses, arrived at independently, because a
    `<!--` quoted mid-sentence is prose and not a comment.

    This scan was itself wrong on first run and the census is what said so: it
    ended comment state at any heading, which made two tasks' template
    placeholders look like live ACs. The predicate was right and the reference
    was not. Recorded here because a census whose reference is never wrong is a
    census nobody has actually run.
    """
    n, in_human, in_comment = 0, False, False
    for line in body.splitlines():
        s = line.strip()
        if in_comment:
            if "-->" in s:
                in_comment = False
            continue
        if s.startswith("<!--") and "-->" not in s:
            in_comment = True
            continue
        if "<!--" in s and "-->" in s:
            s = re.sub(r"<!--.*?-->", "", s).strip()
        if re.match(r"^#{1,3} ", s):
            in_human = bool(re.match(r"^### Human\s*$", s))
            continue
        if in_human and re.match(r"^-\s*\[ \]", s):
            n += 1
    return n


def test_census_both_scans_agree_across_the_live_corpus():
    disagreements = []
    for d in ("active", "completed"):
        for f in sorted((ROOT / ".tasks" / d).glob("T-*.md")):
            body = f.read_text(errors="replace")
            a, b = count_unchecked_human_acs(body), _independent_scan(body)
            if a != b:
                disagreements.append(f"{f.name}: predicate={a} independent={b}")
    assert not disagreements, (
        f"{len(disagreements)} task(s) where the queue predicate and an "
        f"independent scan disagree:\n  " + "\n  ".join(disagreements[:20])
    )
