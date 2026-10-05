"""T-3841 (055): the arc close form pre-fills the decision with the close
recommendation shown above it, the way the demo field is pre-filled, so that
submitting unchanged records the agent's verdict + rationale instead of
`decision: null` ("Decision: unspecified").

Scratch project only: task files in tmp_path, arc dicts injected via `_read_arc`,
and `subprocess.run` captured so no real `fw arc close` runs.
"""

import html as html_mod
import re
import sys
import types

import pytest

sys.path.insert(0, ".")

REC = ("## Recommendation\n\n**Recommendation:** CLOSE\n\n**Rationale:** The headline\n"
       "mechanic fired on a fresh substrate.\n\n**Evidence:**\n- docs/reports/probe.md\n\n## Updates\n")
EXPECTED = ("CLOSE — The headline mechanic fired on a fresh substrate. "
            "(agent recommendation, T-902)")


def _task(root, tid, body):
    d = root / ".tasks" / "completed"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{tid}-probe.md").write_text(f"---\nid: {tid}\n---\n\n{body}")


@pytest.fixture()
def scratch(tmp_path, monkeypatch):
    from web.blueprints import arcs

    _task(tmp_path, "T-901", "## Recommendation\n\n<!-- template -->\n")
    _task(tmp_path, "T-902", REC)
    base = {"status": "in-progress", "headline_mechanic": "The operator sees a probe."}
    registry = {
        "withrec": dict(base, id="arc-801", slug="withrec", name="With", anchor_task="T-901",
                        close_task="T-902"),
        "norec": dict(base, id="arc-802", slug="norec", name="Without", anchor_task="T-901"),
        # T-3894: only the ANCHOR carries a recommendation (the continuous-run case)
        "anchoronly": dict(base, id="arc-803", slug="anchoronly", name="Anchor only",
                           anchor_task="T-902"),
    }
    monkeypatch.setattr(arcs, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(arcs, "_read_arc", lambda i: dict(registry[i]) if i in registry else None)
    monkeypatch.setattr(arcs, "_resolve_constituents", lambda _a: [])
    return arcs


@pytest.fixture()
def client(scratch):
    from web.app import app

    app.config["TESTING"] = True
    app.config["WTF_CSRF_ENABLED"] = False
    return app.test_client()


def _textarea(page):
    m = re.search(r'<textarea id="decision"[^>]*>(.*?)</textarea>', page, re.S)
    assert m, "decision textarea missing"
    return html_mod.unescape(m.group(1))


def test_suggested_decision_is_one_line_with_source(scratch):
    rec = scratch._anchor_recommendation(scratch._read_arc("withrec"))
    assert scratch._suggested_decision(rec) == EXPECTED


def test_get_prefills_the_decision(client):
    page = client.get("/arcs/withrec/close").get_data(as_text=True)
    assert _textarea(page) == EXPECTED
    assert 'data-testid="decision-prefilled"' in page


def test_t3894_anchor_only_recommendation_is_shown_but_never_prefilled(client):
    """Operator 2026-10-05: continuous-run's close form proposed its anchor's June
    'GO — spike walk completed' as the closing verdict of an arc that does not work."""
    page = client.get("/arcs/anchoronly/close").get_data(as_text=True)
    assert _textarea(page) == ""
    assert 'data-testid="decision-prefilled"' not in page
    assert 'data-testid="anchor-not-closeout"' in page
    m = re.search(r'id="demo_value"[^>]*value="([^"]*)"', page, re.S)
    assert m and m.group(1) == "", "an anchor's report must not be offered as demo evidence"


def test_t3894_close_task_recommendation_still_prefills_decision_and_demo(client):
    page = client.get("/arcs/withrec/close").get_data(as_text=True)
    assert _textarea(page) == EXPECTED
    assert 'data-testid="anchor-not-closeout"' not in page
    m = re.search(r'id="demo_value"[^>]*value="([^"]*)"', page, re.S)
    assert m and m.group(1) == "docs/reports/probe.md"


def test_t3893_greyed_out_close_button_says_why(client):
    """Operator 2026-10-05: 'the button is still greyed out' with no reason.
    The page carries a live reason line and both messages the gate can need."""
    page = client.get("/arcs/norec/close").get_data(as_text=True)
    assert 'data-testid="submit-why"' in page and 'aria-live="polite"' in page
    assert "Close is disabled: add demo evidence" in page
    assert "the justification needs at least 30 characters" in page
    # the gate conditions themselves are unchanged
    assert "jLen < 30" in page and "!((demoVal.value || '').trim())" in page


def test_no_recommendation_leaves_the_decision_empty(client):
    page = client.get("/arcs/norec/close").get_data(as_text=True)
    assert _textarea(page) == ""
    assert 'data-testid="decision-prefilled"' not in page


def _csrf(client, route):
    page = client.get(route).get_data(as_text=True)
    m = re.search(r'name="_csrf_token" value="([^"]*)"', page)
    return m.group(1) if m else ""


def test_post_rerender_keeps_the_operator_text(client):
    # demo_mode=path with no value is refused before any subprocess runs.
    route = "/arcs/withrec/close"
    resp = client.post(route, data={"_csrf_token": _csrf(client, route), "demo_mode": "path",
                                    "demo_value": "", "decision": ""})
    page = resp.get_data(as_text=True)
    assert "Submit rejected" in page
    assert _textarea(page) == "", "an operator who cleared the field is not overridden"


def test_unchanged_submit_passes_the_recommendation_as_decision(client, scratch, monkeypatch):
    calls = []

    def fake_run(cmd, **_kw):
        calls.append(cmd)
        return types.SimpleNamespace(returncode=0, stdout="", stderr="")

    monkeypatch.setattr(scratch.subprocess, "run", fake_run)
    route = "/arcs/withrec/close"
    prefilled = _textarea(client.get(route).get_data(as_text=True))
    resp = client.post(route, data={"_csrf_token": _csrf(client, route), "demo_mode": "url",
                                    "demo_value": "https://example.invalid/demo",
                                    "decision": prefilled})
    assert resp.status_code in (302, 303), resp.get_data(as_text=True)[:500]
    close_calls = [c for c in calls if "close" in c]
    assert close_calls, calls
    cmd = close_calls[-1]
    assert cmd[cmd.index("--decision") + 1] == EXPECTED
