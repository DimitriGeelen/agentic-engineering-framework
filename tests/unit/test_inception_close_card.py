"""T-3180: a decided inception must have a way to close it.

THE GAP. T-3175 made decided-but-unclosed inceptions visible on /approvals and told the
operator, in copy shipped with that fix, "Close it from /inception/T-XXXX". Enumerating
every `action=` on that page returned exactly one: /inception/<id>/decide. There was no
close control. /review/<id> 302s to the same page, so both routes converged on a form
that only re-decides — the operator was pointed at a dead end by the fix for the original
problem, which is the same shape one step further along.

WHY THE SILENCE CONTROLS CARRY THE WEIGHT. "Show a close button when the inception is
decided" and "show a close button" are the same diff under any test that only checks the
decided case. Three negatives pin the boundary: pending (nothing to close), DEFER (a park
awaiting a date, not an action — the same exclusion `lib/decided_unclosed.CONCLUDING`
makes), and completed/ (already closed, which is the whole point).
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "lib"))

import decided_unclosed  # noqa: E402


def _fm(**kw):
    base = {
        "id": "T-1",
        "workflow_type": "inception",
        "_location": "active",
        "status": "started-work",
    }
    base.update(kw)
    return base


GO = "**Decision**: GO\n"


# --- the blueprint helper shares ONE predicate with /approvals -------------

def test_blueprint_helper_agrees_with_the_shared_predicate():
    """The bug was two surfaces answering 'is this decided' independently.

    /approvals said the decision was recorded; /inception offered to re-decide it. This
    asserts they cannot drift apart again — the blueprint delegates rather than
    re-deriving.
    """
    from web.blueprints.inception import _is_decided_unclosed

    for fm, body in (
        (_fm(), GO),
        (_fm(), "**Decision**: NO-GO\n"),
        (_fm(), "**Decision**: DEFER\n"),
        (_fm(), "still exploring"),
        (_fm(status="work-completed"), GO),
        (_fm(_location="completed"), GO),
        (_fm(workflow_type="build"), GO),
    ):
        assert _is_decided_unclosed(fm, body) == decided_unclosed.is_decided_unclosed(
            fm, body
        ), f"blueprint diverged from lib on {body!r} / {fm}"


def test_blueprint_helper_fails_closed_on_bad_input():
    """A close button that appears when it should not is worse than none at all —
    it invites the operator to close something the framework has not agreed is done."""
    from web.blueprints.inception import _is_decided_unclosed

    assert _is_decided_unclosed(None, None) is False
    assert _is_decided_unclosed({}, "") is False


# --- the rendered page -----------------------------------------------------

def _client():
    from web.app import app

    return app.test_client()


def _decided_open_inception():
    """A real decided-unclosed inception from the corpus, or skip.

    Deliberately not a fixture: the render is what the operator sees, and pinning it
    against a synthetic task would not have caught the original defect either — the
    original defect WAS in the render, against real tasks.
    """
    import yaml

    for f in sorted((REPO / ".tasks" / "active").glob("T-*.md")):
        txt = f.read_text()
        if not txt.startswith("---"):
            continue
        try:
            end = txt.index("\n---", 3)
            fm = yaml.safe_load(txt[3:end]) or {}
        except Exception:
            continue
        fm["_location"] = "active"
        if decided_unclosed.is_decided_unclosed(fm, txt[end + 4:]):
            return fm["id"]
    return None


def test_decided_open_inception_page_offers_a_close_control():
    task_id = _decided_open_inception()
    if not task_id:
        import pytest

        pytest.skip("no decided-unclosed inception in the corpus right now")
    html = _client().get(f"/inception/{task_id}").get_data(as_text=True)
    assert "close-inception" in html
    assert f"/api/task/{task_id}/complete" in html


def test_pending_inception_page_offers_no_close_control():
    """Silence control 1: nothing has been decided, so there is nothing to close."""
    import yaml

    for f in sorted((REPO / ".tasks" / "active").glob("T-*.md")):
        txt = f.read_text()
        if not txt.startswith("---"):
            continue
        try:
            end = txt.index("\n---", 3)
            fm = yaml.safe_load(txt[3:end]) or {}
        except Exception:
            continue
        if fm.get("workflow_type") != "inception":
            continue
        if decided_unclosed.extract_decision(txt[end + 4:]) is not None:
            continue
        html = _client().get(f"/inception/{fm['id']}").get_data(as_text=True)
        assert "close-inception" not in html, f"{fm['id']} is undecided but offers close"
        return
    import pytest

    pytest.skip("no pending inception in the corpus right now")
