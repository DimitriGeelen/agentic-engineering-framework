"""T-2075 (T-2064 GO scope): canonical needs-human-review predicate.

Pins the contract of `web.shared.count_unchecked_human_acs` against the five
fixture cases enumerated in the T-2064 inception:

  a. Empty body → 0
  b. Body without `## Acceptance Criteria` → 0
  c. AC block without `### Human` subsection → 0 (all-Agent tasks shouldn't queue)
  d. Human block with only HTML-commented template stub ACs → 0
     (otherwise the template's `[REVIEW] Voice/tone…` placeholder falsely
     admits every fresh task into /approvals; this was the L-298 / T-1581
     class on the CLI side that we now centralise.)
  e. Human block with mix of checked + unchecked + Agent ACs + Verification
     `[ ]` outside the Human subsection → counts ONLY the unchecked ones inside
     `### Human`.

If any of these change, the two surfaces (/approvals web + `fw review-queue`
CLI) silently drift apart — that's the whole point of the T-2064 GO.
"""
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from web.shared import count_unchecked_human_acs, needs_human_review


def test_a_empty_body_returns_zero():
    assert count_unchecked_human_acs("") == 0
    assert count_unchecked_human_acs(None) == 0
    assert needs_human_review("") is False


def test_b_no_acceptance_criteria_returns_zero():
    body = "# Title\n\n## Context\n\nSome context.\n"
    assert count_unchecked_human_acs(body) == 0
    assert needs_human_review(body) is False


def test_c_agent_only_block_returns_zero():
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [ ] Build the thing\n"
        "- [ ] Test the thing\n"
        "\n"
        "## Verification\n"
        "- [ ] this is not an AC, it's verification stub\n"
    )
    assert count_unchecked_human_acs(body) == 0
    assert needs_human_review(body) is False


def test_d_html_commented_template_stub_returns_zero():
    """The canonical task template's Human block contains an example
    `- [ ] [REVIEW] Dashboard renders correctly` AC inside `<!-- ... -->`.
    That MUST NOT count — otherwise every fresh task lands in /approvals
    the moment it's created.
    """
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [x] Done\n\n"
        "### Human\n"
        "<!-- Criteria requiring human verification.\n"
        "     Each criterion MUST include Steps/Expected/If-not.\n"
        "     Example:\n"
        "       - [ ] [REVIEW] Dashboard renders correctly\n"
        "         Steps: ...\n"
        "-->\n"
    )
    assert count_unchecked_human_acs(body) == 0
    assert needs_human_review(body) is False


def test_e_mixed_blocks_counts_only_unchecked_human():
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [ ] Agent A — unchecked, must NOT count\n"
        "- [x] Agent B — checked, ignored either way\n"
        "\n"
        "### Human\n"
        "- [x] Human A — checked, doesn't count\n"
        "- [ ] [REVIEW] Human B — unchecked, MUST count\n"
        "- [ ] [REVIEW] Human C — unchecked, MUST count\n"
        "<!-- example: - [ ] commented stub, must not count -->\n"
        "\n"
        "## Verification\n"
        "- [ ] Verification line with [ ] checkbox-ish syntax — must NOT count\n"
    )
    assert count_unchecked_human_acs(body) == 2
    assert needs_human_review(body) is True


def test_f_human_block_with_all_checked_returns_zero():
    """Belt-and-braces: a partial-complete task where every Human AC has been
    ticked should drop OUT of the queue immediately."""
    body = (
        "## Acceptance Criteria\n\n"
        "### Agent\n"
        "- [x] All done\n"
        "\n"
        "### Human\n"
        "- [x] [REVIEW] Looks fine\n"
        "- [x] [RUBBER-STAMP] Published\n"
    )
    assert count_unchecked_human_acs(body) == 0
    assert needs_human_review(body) is False
