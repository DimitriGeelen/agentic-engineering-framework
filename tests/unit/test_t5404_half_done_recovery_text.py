"""T-5404: after a half-done inception decision, Watchtower says who can finish it.

Origin: 150-skills-manager C-010 (2026-11-24). When `fw inception decide` stopped
after saving the decision, Watchtower told the operator "the agent session can
recover this (fw inception sweep); no action needed from you". For an
`owner: human` inception (the usual case) that is false: the sweep closes through
update-task.sh, which refuses --skip-sovereignty in an agent session (T-3586).

Pinned here, for both half-done outcomes (gate refused, chain interrupted) and
both owners:
  - owner: human  -> the operator gets one copy-paste line
                     (`cd <root> && <fw> inception sweep T-NNN`) and is never told
                     "no action needed".
  - owner: agent  -> the agent path is named and "no action needed" may appear.
  - the non-htmx form path carries the same line in its ?warning= redirect.
"""
from __future__ import annotations

import importlib
import sys
from pathlib import Path
from urllib.parse import unquote_plus

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

HALF_DONE = """---
id: {tid}
name: "fixture"
status: started-work
workflow_type: inception
owner: {owner}
---
# {tid}: fixture

## Decision

**Decision**: GO

**Rationale**: test

## Updates
"""


@pytest.fixture
def app_env(tmp_path, monkeypatch):
    for d in (".context/working", ".tasks/active", ".tasks/completed"):
        (tmp_path / d).mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.delenv("CLAUDECODE", raising=False)
    import web.shared
    import web.blueprints.inception
    importlib.reload(web.shared)
    importlib.reload(web.blueprints.inception)
    import web.app
    importlib.reload(web.app)
    app = web.app.create_app()
    app.config["TESTING"] = True
    inc = web.blueprints.inception
    monkeypatch.setattr(inc, "_commit_decision", lambda *a, **k: (True, "nothing to commit"))
    with app.test_client() as c:
        yield c, tmp_path, inc


def _post(c, tid, htmx=True):
    with c.session_transaction() as sess:
        sess["_csrf_token"] = "tok"
    return c.post(f"/inception/{tid}/decide",
                  data={"decision": "go", "rationale": "r", "_csrf_token": "tok"},
                  headers={"HX-Request": "true"} if htmx else {})


GATE = dict(err="ERROR: Cannot complete — P-010 unchecked acceptance criteria", rc=1)
KILLED = dict(err="", rc=-9, run_dir=".context/working/decide/run")


def _setup(app_env, monkeypatch, tid, owner, result):
    c, p, inc = app_env
    (p / f".tasks/active/{tid}-x.md").write_text(HALF_DONE.format(tid=tid, owner=owner))
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(**result))
    return c, p


@pytest.mark.parametrize("result", [GATE, KILLED], ids=["gate-refused", "interrupted"])
def test_operator_owned_gets_one_line_and_no_false_all_clear(app_env, monkeypatch, result):
    c, p = _setup(app_env, monkeypatch, "T-9811", "human", result)
    html = _post(c, "T-9811").get_data(as_text=True)
    assert "Decision recorded" in html
    assert "only you can finish it" in html
    assert f"cd {p} &amp;&amp; " in html            # escaped copy-paste line
    assert "inception sweep T-9811" in html
    assert "no action needed" not in html
    assert "the agent session can recover this" not in html
    assert "the agent session can finish it" not in html.lower()


def test_operator_owned_gate_refused_still_shows_the_reason(app_env, monkeypatch):
    c, _ = _setup(app_env, monkeypatch, "T-9812", "human", GATE)
    html = _post(c, "T-9812").get_data(as_text=True)
    assert "blocked by a framework gate" in html
    assert "Once the blocker below is fixed" in html
    assert "P-010 unchecked acceptance criteria" in html


@pytest.mark.parametrize("result", [GATE, KILLED], ids=["gate-refused", "interrupted"])
def test_agent_owned_names_the_agent_path(app_env, monkeypatch, result):
    c, _ = _setup(app_env, monkeypatch, "T-9813", "agent", result)
    html = _post(c, "T-9813").get_data(as_text=True)
    assert "The agent session can finish it" in html
    assert "inception sweep T-9813" in html
    assert "no action needed from you unless it persists" in html
    assert "only you can finish it" not in html


@pytest.mark.parametrize("result", [GATE, KILLED], ids=["gate-refused", "interrupted"])
def test_form_path_redirect_carries_the_operator_line(app_env, monkeypatch, result):
    c, p = _setup(app_env, monkeypatch, "T-9814", "human", result)
    resp = _post(c, "T-9814", htmx=False)
    assert resp.status_code in (302, 303)
    loc = unquote_plus(resp.headers["Location"])
    assert "only you can finish it" in loc
    assert f"cd {p} && " in loc and "inception sweep T-9814" in loc
    assert "no action needed" not in loc
