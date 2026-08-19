"""T-3078: /approvals must not assert an agent asked when none did.

The Tier 0 section subtitle was the literal string "Agent blocked — requires
your decision", emitted for every card regardless of what produced it. For the
cards T-3077's governance suite filed against the live queue it was false: no
agent was blocked, a test was, and one of those cards read "RECURSIVE DELETE:
Targets root filesystem (/)". The operator opened /approvals on 2026-08-18, saw
it, and asked why — and the page had no way to answer, because a card recorded
no origin at all.

These tests pin two things: the subtitle is derived from the cards actually
pending, and a card with no provenance is labelled unknown rather than being
quietly presented as an agent request. The second matters most — every card
written before this change lacks an `origin:` key, and the failure mode of
getting it wrong is the original bug wearing new wording.
"""

import re
import sys

import pytest

sys.path.insert(0, ".")

from web.blueprints.approvals import _tier0_origin_summary  # noqa: E402


def _pending(kind=None, **extra):
    card = {"status": "pending", **extra}
    if kind is not None:
        card["origin"] = {"kind": kind}
    return card


# ── the derived subtitle ───────────────────────────────────────────────────

def test_no_pending_cards_yields_no_claim():
    """Empty string, so the caller can omit the clause entirely rather than
    render a sentence about zero things."""
    assert _tier0_origin_summary([]) == ""


def test_a_single_agent_request_is_named_as_one():
    assert _tier0_origin_summary([_pending("agent")]) == "1 agent request"


def test_test_artefacts_are_named_as_test_artefacts():
    """The T-3077 case. This is the string that should have appeared on the
    operator's screen instead of "Agent blocked"."""
    assert _tier0_origin_summary([_pending("test")] * 2) == "2 test artefacts"


def test_a_mixed_queue_reports_both():
    got = _tier0_origin_summary([_pending("agent"), _pending("test"), _pending("test")])
    assert got == "1 agent request, 2 test artefacts"


def test_the_summary_actually_varies_with_input():
    """L-616 guard: a function returning a constant would satisfy each
    assertion above if they were read one at a time."""
    seen = {
        _tier0_origin_summary([_pending("agent")]),
        _tier0_origin_summary([_pending("test")]),
        _tier0_origin_summary([_pending("human")]),
        _tier0_origin_summary([_pending(None)]),
    }
    assert len(seen) == 4


# ── backward compatibility: cards written before provenance existed ────────

def test_a_card_with_no_origin_key_is_unknown_not_agent():
    """Every card on disk before T-3078 has no `origin:`. Defaulting those to
    "agent" would reproduce the exact false claim this task removes."""
    assert _tier0_origin_summary([{"status": "pending"}]) == "1 unknown origin"


def test_a_null_origin_is_unknown():
    assert _tier0_origin_summary([{"status": "pending", "origin": None}]) == "1 unknown origin"


def test_an_unrecognised_kind_falls_back_to_unknown():
    """Fails closed. A future `kind` this version does not know about must not
    be rendered as a bare word the operator has to guess at."""
    assert _tier0_origin_summary([_pending("something-new")]) == "1 unknown origin"


def test_expired_cards_are_not_counted():
    """Expired cards are not offerable, so they are not what the subtitle is
    describing."""
    assert _tier0_origin_summary([{"status": "expired", "origin": {"kind": "agent"}}]) == ""


# ── the template no longer carries the unconditional claim ─────────────────

def test_template_has_no_hardcoded_agent_blocked_subtitle():
    """The defect was a literal in the template, so assert on the template.

    A blueprint-level test cannot see this: the string lived in HTML and no
    Python code path referenced it.
    """
    html = open("web/templates/_approvals_content.html").read()
    # Strip {# … #} first: the comment explaining the removal quotes the string
    # it removed, and a naive grep cannot tell the explanation from the defect.
    live = re.sub(r"\{#.*?#\}", "", html, flags=re.DOTALL)
    assert "Agent blocked — requires your decision" not in live
    assert "tier0_origin_summary" in live


def test_template_renders_the_origin_badge_and_the_unknown_warning():
    html = open("web/templates/_approvals_content.html").read()
    assert "origin-badge" in html
    # The unknown branch must say something, not render an empty line.
    assert "No provenance recorded" in html


@pytest.fixture()
def client():
    from web.app import app

    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_approvals_page_still_renders(client):
    """Integration backstop: the template changes must not 500 the page. The
    queue is usually empty, which is the state the page spends most of its life
    in and therefore the one most worth pinning."""
    resp = client.get("/approvals")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert not re.search(r"Agent blocked\s*—\s*requires your decision", body)
