"""T-3843 (ported from 055 T-454): an arc close carries the agent's close
recommendation, as a task review does.

Scratch project only, never this repo's arcs: task files live in tmp_path and
the arc dicts are injected by monkeypatching `_read_arc`, so the assertions
cannot drift with the live corpus.

  * the close-out task (`close_task:`) wins over the anchor;
  * the anchor is the fallback, and the card says which one it read;
  * with neither, both pages show a visible "no close recommendation" card that
    names the expected task, and the close form is still there.
"""

import sys

import pytest

sys.path.insert(0, ".")

REC = ("## Recommendation\n\n**Recommendation:** CLOSE\n\n**Rationale:** {}\n\n"
       "**Evidence:**\n- docs/reports/probe-close.md\n\n## Updates\n")
TEMPLATE_ONLY = "## Recommendation\n\n<!-- **Recommendation:** template only -->\n\n## Updates\n"


def _task(root, tid, body, where="completed"):
    d = root / ".tasks" / where
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{tid}-probe.md").write_text(
        f"---\nid: {tid}\nname: probe\nstatus: work-completed\n---\n\n{body}")


def _arc(slug, anchor, close_task=None):
    a = {"id": f"arc-9{len(slug)}", "slug": slug, "name": f"Probe {slug}",
         "status": "in-progress", "anchor_task": anchor,
         "headline_mechanic": "The operator sees a probe."}
    if close_task:
        a["close_task"] = close_task
    return a


@pytest.fixture()
def scratch(tmp_path, monkeypatch):
    from web.blueprints import arcs

    _task(tmp_path, "T-901", REC.format("anchor text, the fallback only"))
    _task(tmp_path, "T-902", REC.format("close-out text wins"))
    _task(tmp_path, "T-903", REC.format("anchor fallback text"))
    _task(tmp_path, "T-904", TEMPLATE_ONLY)
    _task(tmp_path, "T-905", TEMPLATE_ONLY, where="active")
    registry = {
        "withrec": _arc("withrec", "T-901", close_task="T-902"),
        "fallback": _arc("fallback", "T-903"),
        "norec": _arc("norec", "T-904", close_task="T-905"),
        "nothing": _arc("nothing", ""),
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

def test_helper_prefers_close_task(scratch):
    rec = scratch._anchor_recommendation(scratch._read_arc("withrec"))
    assert rec["present"] and rec["verdict"] == "CLOSE"
    assert rec["source"] == "close_task" and rec["anchor_id"] == "T-902"
    assert "close-out text wins" in rec["rationale"]


def test_helper_falls_back_to_anchor(scratch):
    rec = scratch._anchor_recommendation(scratch._read_arc("fallback"))
    assert rec["present"] and rec["source"] == "anchor_task" and rec["anchor_id"] == "T-903"


def test_helper_template_only_is_not_a_recommendation(scratch):
    rec = scratch._anchor_recommendation(scratch._read_arc("norec"))
    assert not rec["present"]
    assert rec["expected_task"] == "T-905"
    assert rec["source"] == "" and rec["anchor_id"] == ""


# -- the close and review pages ----------------------------------------------

def test_close_page_shows_the_close_task_recommendation(client):
    html = client.get("/arcs/withrec/close").get_data(as_text=True)
    assert "verdict-CLOSE" in html
    assert "close-out text wins" in html
    assert "anchor text, the fallback only" not in html
    assert "from close-out task" in html
    assert "docs/reports/probe-close.md" in html, "the demo field is pre-filled"
    assert 'data-testid="arc-rec-missing"' not in html


def test_close_page_falls_back_to_the_anchor(client):
    html = client.get("/arcs/fallback/close").get_data(as_text=True)
    assert "anchor fallback text" in html
    assert "from anchor task" in html


def test_review_page_labels_the_source(client):
    html = client.get("/arcs/withrec/review").get_data(as_text=True)
    assert "from close-out task" in html
    assert 'data-testid="arc-rec-missing"' not in html


def test_close_and_review_pages_show_the_missing_card(client):
    for route in ("/arcs/norec/close", "/arcs/norec/review"):
        resp = client.get(route)
        assert resp.status_code == 200, route
        html = resp.get_data(as_text=True)
        assert 'data-testid="arc-rec-missing"' in html, route
        assert 'href="/tasks/T-905"' in html, route
    close = client.get("/arcs/norec/close").get_data(as_text=True)
    assert "No close recommendation yet" in close
    assert 'action="/arcs/norec/close"' in close, "the operator can still close"


def test_missing_card_without_any_task_tells_where_to_set_it(client):
    html = client.get("/arcs/nothing/close").get_data(as_text=True)
    assert 'data-testid="arc-rec-missing"' in html
    assert "close_task:" in html
