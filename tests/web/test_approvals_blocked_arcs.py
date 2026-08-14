"""T-2986: an arc that meets the closure threshold but is not reviewable says so.

`_load_close_ready_arcs` requires three conditions (in-progress, ratio >= threshold,
anchor `## Recommendation`). The third failing used to produce a bare `continue`, so the
arc left the queue with nothing said anywhere — and a silent exclusion is indistinguishable
from a considered judgement. arc-015 (`onboarding-shape-detection`) sat that way while 2/2
complete with its demo evidence captured under T-2910.

These run against the REAL arc store rather than fixtures. That is the point: the bug was
never in the branch logic, it was in what the live data did to it, and a fixture asserting
the shape of a hand-made arc would have passed throughout the period arc-015 was invisible
(the T-2980/T-2985 lesson). The trade-off is that the tests must not hard-code which arc is
blocked — arc-015 will stop being blocked the moment someone writes T-2718's Recommendation,
which is the outcome this change exists to cause. So they assert the *contract* and skip
cleanly when the live store has no example of a given state.
"""

import re
import sys

import pytest

sys.path.insert(0, ".")


@pytest.fixture()
def client():
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client()


@pytest.fixture()
def rows():
    from web.blueprints.approvals import _load_close_ready_arcs

    return _load_close_ready_arcs()


def _card(html, slug):
    """The one card for `slug`, bounded by the next card or end of document."""
    m = re.search(
        rf'data-arc-slug="{re.escape(slug)}".*?(?=data-arc-slug=|</body>)', html, re.S
    )
    return m.group(0) if m else ""


def test_every_row_carries_the_blocked_reason_field(rows):
    """Contract: the field always exists, empty meaning actionable."""
    assert rows, "no arcs met the closure threshold — cannot judge the contract"
    for r in rows:
        assert "blocked_reason" in r, f"{r['slug']} predates the T-2986 field"
        assert isinstance(r["blocked_reason"], str)


def test_actionable_rows_keep_a_verdict_and_blocked_rows_do_not(rows):
    """A blocked arc must not display an advisory it does not have.

    Showing GO on an arc whose anchor has no Recommendation invites a close on evidence
    nobody has written down — the specific harm that justifies not simply listing
    everything.
    """
    for r in rows:
        if r["blocked_reason"]:
            assert not r["verdict"], (
                f"{r['slug']} is blocked but shows verdict {r['verdict']!r}"
            )
        else:
            assert r["verdict"], f"{r['slug']} is actionable but has no verdict"


def test_blocked_reason_names_what_unblocks_it(rows):
    """"Blocked" without a remedy just relocates the confusion."""
    blocked = [r for r in rows if r["blocked_reason"]]
    if not blocked:
        pytest.skip("no blocked arc in the live store — nothing to judge")
    for r in blocked:
        assert "Recommendation" in r["blocked_reason"] or "anchor_task" in r["blocked_reason"], (
            f"{r['slug']}'s blocked_reason does not name the missing piece: "
            f"{r['blocked_reason']!r}"
        )


def test_threshold_still_bounds_the_queue(rows):
    """T-2986 widens by one condition only. An unbounded queue is the T-2038 class."""
    for r in rows:
        assert r["completion_ratio"] >= 0.80, (
            f"{r['slug']} is below threshold at {r['completion_ratio']:.2f} — the "
            f"blocked-arc branch must not have relaxed the completion filter"
        )


def test_blocked_arc_renders_without_a_close_action(client, rows):
    """The rendered card must not offer a decision that cannot be made."""
    blocked = [r for r in rows if r["blocked_reason"]]
    if not blocked:
        pytest.skip("no blocked arc in the live store — nothing to render")
    html = client.get("/approvals").get_data(as_text=True)
    for r in blocked:
        card = _card(html, r["slug"])
        assert card, f"{r['slug']} is in the loader output but not on the page"
        assert f'/arcs/{r["slug"]}/close' not in card, (
            f"{r['slug']} is blocked but its card still offers Approve / Override"
        )
        assert "Not yet reviewable" in card
        if r["anchor"]:
            assert r["anchor"] in card, (
                "the card does not name the anchor task, so the operator cannot act "
                "without reading approvals.py to find out why the arc is listed"
            )


def test_actionable_arc_still_renders_its_close_action(client, rows):
    """The pre-existing rows must not regress — this was additive."""
    actionable = [r for r in rows if not r["blocked_reason"]]
    if not actionable:
        pytest.skip("no actionable arc in the live store")
    html = client.get("/approvals").get_data(as_text=True)
    for r in actionable:
        card = _card(html, r["slug"])
        assert card, f"{r['slug']} disappeared from the page"
        assert f'/arcs/{r["slug"]}/close' in card, (
            f"{r['slug']} is close-ready but lost its Approve / Override action"
        )


def test_approvals_page_still_renders(client):
    assert client.get("/approvals").status_code == 200
