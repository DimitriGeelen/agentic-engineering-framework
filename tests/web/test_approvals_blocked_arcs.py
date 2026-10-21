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


def _admitted(r, threshold=0.80):
    """The T-3552 predicate: L1 and L2 passed, or (legs uncomputable) the old ratio."""
    legs = r.get("readiness")
    if legs is not None:
        return bool(legs["l1"]["passed"] and legs["l2"]["passed"])
    return r["completion_ratio"] >= threshold


def test_threshold_still_bounds_the_queue(rows):
    """T-2986 widens by one condition only. An unbounded queue is the T-2038 class.

    T-4329: the bound is no longer the 80% completion ratio. T-3552 replaced it
    with quadrant exhaustion (readiness legs L1 + L2); the ratio applies only as
    the fallback when the legs cannot be computed. This asserted the old ratio
    and went red once a live arc passed L1+L2 below 80% (dispatch-safety, 0.58).
    """
    for r in rows:
        assert _admitted(r), (
            f"{r['slug']} is in the queue without passing the readiness bound "
            f"(readiness={r.get('readiness')!r}, ratio={r['completion_ratio']:.2f})"
        )


@pytest.fixture()
def fake_store(tmp_path, monkeypatch):
    """A two-arc store whose readiness and ratio the test controls — the live
    store cannot be relied on to hold an example of each state."""
    import web.blueprints.approvals as ap
    import web.blueprints.arcs as arcs

    (tmp_path / ".context" / "arcs").mkdir(parents=True)
    for slug in ("full", "partial"):
        (tmp_path / ".context" / "arcs" / f"{slug}.yaml").write_text(
            f"slug: {slug}\nid: arc-{slug}\nstatus: in-progress\nanchor_task: T-1\n"
        )
    ratio = {"full": 1.0, "partial": 0.25}
    monkeypatch.setattr(ap, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(arcs, "_resolve_constituents", lambda arc: arc["slug"])
    monkeypatch.setattr(
        arcs, "_completion_stats",
        lambda slug: {"ratio": ratio[slug], "completed": 0, "total": 0},
    )
    monkeypatch.setattr(
        arcs, "_anchor_recommendation",
        lambda arc: {"present": True, "verdict": "CLOSE", "anchor_id": "T-1"},
    )
    state = {}

    def legs(arc, constituents):
        v = state[arc["slug"]]
        return None if v is None else {"l1": {"passed": v}, "l2": {"passed": v}}

    monkeypatch.setattr(ap, "_arc_readiness_legs", legs)
    return state


def _slugs():
    from web.blueprints.approvals import _load_close_ready_arcs

    return sorted(r["slug"] for r in _load_close_ready_arcs())


def test_ratio_alone_no_longer_admits_an_arc(fake_store):
    """A 100%-complete arc that fails L1/L2 stays out; a 25% one that passes is in."""
    fake_store.update({"full": False, "partial": True})
    assert _slugs() == ["partial"]


def test_ratio_is_the_fallback_only_when_readiness_is_uncomputable(fake_store):
    """legs None: the 80% ratio decides, so the queue is never unbounded."""
    fake_store.update({"full": None, "partial": None})
    assert _slugs() == ["full"]


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
