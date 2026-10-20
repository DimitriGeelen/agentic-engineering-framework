"""T-4190 (832 OBS-427) — a decide refusal the sanitizer filters to nothing must say so.

`operator_facing_stderr` drops every line written for agents (bypass flags, Tier-2
env vars). A gate refusal made only of such lines therefore filters to ''. Both
decide failure paths used `filtered or <fallback>`, and the fallback could not tell
"the CLI said nothing" from "the CLI said something the operator must not see":
  - redirect path → "Unknown error from fw inception decide"
  - htmx path     → the T-3539 text claiming NO output on either stream (false)

These tests pin the filtered-to-empty case on both paths, plus the truly-empty
control that must keep the T-3539 wording.
"""

import importlib
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]

# Every line of this is agent-facing bypass guidance: it filters to ''.
BYPASS_ONLY = (
    "Refused. Bypass: --skip-disposition-gate x\n"
    "  FW_SKIP_DISPOSITION_GATE=1 (logged Tier-2)"
)


@pytest.fixture
def client(tmp_path, monkeypatch):
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")

    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    import web.shared
    import web.blueprints.inception
    importlib.reload(web.shared)
    importlib.reload(web.blueprints.inception)
    import web.app
    importlib.reload(web.app)
    app = web.app.create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c, tmp_path


def _setup(monkeypatch, p, task_id, stderr):
    import web.blueprints.inception as inc
    monkeypatch.setattr(inc, "_run_decide", lambda *a, **k: inc._DecideResult(
        out="", err=stderr, rc=1))
    (p / ".tasks" / "active" / f"{task_id}-x.md").write_text(
        f"---\nid: {task_id}\nstatus: started-work\nworkflow_type: inception\n---\n# {task_id}\n")


def _post(c, task_id, htmx):
    with c.session_transaction() as sess:
        sess["_csrf_token"] = "testtoken"
    headers = {"HX-Request": "true"} if htmx else {}
    return c.post(
        f"/inception/{task_id}/decide",
        data={"decision": "go", "rationale": "approved", "_csrf_token": "testtoken"},
        headers=headers,
    )


def test_bypass_only_input_filters_to_empty():
    # Precondition the rest of the file depends on.
    from web.shared import operator_facing_stderr
    assert operator_facing_stderr(BYPASS_ONLY) == ""


def test_redirect_path_names_filtered_refusal(client, monkeypatch):
    c, p = client
    _setup(monkeypatch, p, "T-9190", BYPASS_ONLY)
    resp = _post(c, "T-9190", htmx=False)
    assert resp.status_code == 302
    err = parse_qs(urlparse(resp.headers["Location"]).query)["error"][0]
    assert "Unknown error" not in err
    assert "written for agents" in err
    assert "bin/fw task review T-9190" in err
    # The bypass text itself must still not leak to the operator.
    assert "FW_SKIP_DISPOSITION_GATE" not in err
    assert "--skip-disposition-gate" not in err


def test_htmx_path_names_filtered_refusal(client, monkeypatch):
    c, p = client
    _setup(monkeypatch, p, "T-9191", BYPASS_ONLY)
    html = _post(c, "T-9191", htmx=True).get_data(as_text=True)
    assert "Decision not recorded" in html
    assert "NO output on either stream" not in html
    assert "written for agents" in html
    assert "bin/fw task review T-9191" in html
    assert "FW_SKIP_DISPOSITION_GATE" not in html


def test_htmx_truly_empty_keeps_silent_wording(client, monkeypatch):
    c, p = client
    _setup(monkeypatch, p, "T-9192", "")
    html = _post(c, "T-9192", htmx=True).get_data(as_text=True)
    assert "NO output on either stream" in html
    assert "written for agents" not in html


def test_redirect_truly_empty_does_not_claim_agent_message(client, monkeypatch):
    c, p = client
    _setup(monkeypatch, p, "T-9193", "")
    resp = _post(c, "T-9193", htmx=False)
    err = parse_qs(urlparse(resp.headers["Location"]).query)["error"][0]
    assert "written for agents" not in err
    assert "NO output" in err
