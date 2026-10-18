"""T-4320 (peer report from 1023, arc vault-mvp): the arc close page accepts only
a CLOSE or KEEP-OPEN recommendation as the agent's close verdict.

Scratch project only: task files live in tmp_path and the arc dicts are injected
by monkeypatching `_read_arc`, so nothing reads this repo's live arcs.

  * an anchor inception holding only GO → no recommendation card, the missing
    card says the agent has not filed one and names the GO it skipped;
  * GO on the close_task → same, and the card points at the close_task;
  * neither close_task nor anchor_task → missing card naming close_task:;
  * KEEP-OPEN on the close_task → shown as the recommendation.
"""

import sys

import pytest

sys.path.insert(0, ".")

REC = ("## Recommendation\n\n**Recommendation:** {}\n\n**Rationale:** {}\n\n"
       "**Evidence:**\n- docs/reports/probe.md\n\n## Updates\n")


def _task(root, tid, body, where="completed"):
    d = root / ".tasks" / where
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{tid}-probe.md").write_text(
        f"---\nid: {tid}\nname: probe\nstatus: work-completed\n---\n\n{body}")


def _arc(slug, anchor="", close_task=""):
    a = {"id": f"arc-9{len(slug)}", "slug": slug, "name": f"Probe {slug}",
         "status": "in-progress", "headline_mechanic": "The operator sees a probe."}
    if anchor:
        a["anchor_task"] = anchor
    if close_task:
        a["close_task"] = close_task
    return a


@pytest.fixture()
def scratch(tmp_path, monkeypatch):
    from web.blueprints import arcs

    _task(tmp_path, "T-921", REC.format("GO", "opening go text: start the arc"))
    _task(tmp_path, "T-922", REC.format("KEEP-OPEN", "keep-open text"), where="active")
    _task(tmp_path, "T-923", REC.format("DEFER", "deferred text"), where="active")
    registry = {
        "goanchor": _arc("goanchor", anchor="T-921"),
        "goclose": _arc("goclose", anchor="T-921", close_task="T-923"),
        "nothing": _arc("nothing"),
        "keepopen": _arc("keepopen", anchor="T-921", close_task="T-922"),
    }
    monkeypatch.setattr(arcs, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(arcs, "_read_arc", lambda i: dict(registry[i]) if i in registry else None)
    monkeypatch.setattr(arcs, "_resolve_constituents", lambda _a: [])
    return arcs


@pytest.fixture()
def client(scratch):
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client()


# -- the helper ---------------------------------------------------------------

def test_helper_ignores_an_anchor_go(scratch):
    rec = scratch._anchor_recommendation(scratch._read_arc("goanchor"))
    assert not rec["present"]
    assert rec["verdict"] == "?" and rec["source"] == "" and rec["anchor_id"] == ""
    assert rec["ignored_task"] == "T-921" and rec["ignored_verdict"] == "GO"


def test_helper_ignores_a_non_close_verdict_on_close_task(scratch):
    rec = scratch._anchor_recommendation(scratch._read_arc("goclose"))
    assert not rec["present"]
    assert rec["ignored_task"] == "T-923" and rec["ignored_verdict"] == "DEFER"
    assert rec["expected_task"] == "T-923"


def test_helper_with_no_tasks_at_all(scratch):
    rec = scratch._anchor_recommendation(scratch._read_arc("nothing"))
    assert not rec["present"] and rec["expected_task"] == "" and rec["ignored_task"] == ""


def test_helper_accepts_keep_open(scratch):
    rec = scratch._anchor_recommendation(scratch._read_arc("keepopen"))
    assert rec["present"] and rec["verdict"] == "KEEP-OPEN"
    assert rec["source"] == "close_task" and rec["anchor_id"] == "T-922"


# -- the close and review pages ----------------------------------------------

def test_close_page_does_not_show_the_anchor_go(client):
    resp = client.get("/arcs/goanchor/close")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)
    assert 'data-testid="arc-rec-missing"' in html
    assert "The agent has not filed a close recommendation" in html
    assert 'data-testid="arc-rec-ignored"' in html and 'href="/tasks/T-921"' in html
    assert "verdict-badge verdict-GO" not in html
    assert "opening go text" not in html
    assert "close_task: T-XXX" in html, "names the agent action"
    assert 'action="/arcs/goanchor/close"' in html, "the operator can still close"


def test_close_page_points_at_a_close_task_holding_defer(client):
    html = client.get("/arcs/goclose/close").get_data(as_text=True)
    assert 'data-testid="arc-rec-missing"' in html
    assert "verdict-badge verdict-DEFER" not in html
    assert 'href="/tasks/T-923"' in html


def test_close_page_with_neither_task(client):
    html = client.get("/arcs/nothing/close").get_data(as_text=True)
    assert 'data-testid="arc-rec-missing"' in html
    assert "The agent has not filed a close recommendation" in html
    assert "close_task: T-XXX" in html


def test_close_page_shows_keep_open(client):
    html = client.get("/arcs/keepopen/close").get_data(as_text=True)
    assert "verdict-badge verdict-KEEP-OPEN" in html and "keep-open text" in html
    assert 'data-testid="arc-rec-missing"' not in html


def test_review_page_does_not_show_the_anchor_go(client):
    html = client.get("/arcs/goanchor/review").get_data(as_text=True)
    assert 'data-testid="arc-rec-missing"' in html
    assert 'data-testid="arc-rec-ignored"' in html
    assert "verdict-badge verdict-GO" not in html and "opening go text" not in html
