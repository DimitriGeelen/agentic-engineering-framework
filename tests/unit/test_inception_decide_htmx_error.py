"""T-2051 — htmx decide-failure must surface the reason inline, not return 500.

Origin incident (T-2030): the human clicked GO from /approvals 3×; the first two
POSTs returned HTTP 500 because `fw inception decide` rejected the not-yet-ready
task ("## Recommendation section required"). The /approvals decide button uses
`hx-post` + `hx-swap="outerHTML"`, and htmx does not swap non-2xx responses, so
the `.go-decision` block was never replaced — the human saw the unchanged GO
button and re-clicked, never seeing the reason.

These tests pin the htmx branch of `record_decision`:
  - failure (not ok, primary not landed) → HTTP 200 with a swappable error
    fragment that contains the reason (NOT 500)
  - success → the decision card (unchanged)

Tests use Flask test_client against an isolated PROJECT_ROOT.
"""

import importlib
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]


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


def _patch_fw(monkeypatch, stdout, stderr, ok):
    import web.blueprints.inception as inc
    monkeypatch.setattr(inc, "run_fw_command", lambda *a, **k: (stdout, stderr, ok))


def _write_active_task(p, task_id, *, with_decision=False):
    body = f"---\nid: {task_id}\nstatus: started-work\nworkflow_type: inception\n---\n# {task_id}\n"
    if with_decision:
        body += "\n## Decision\n\n**Decision**: GO\n"
    (p / ".tasks" / "active" / f"{task_id}-x.md").write_text(body)


def _post_decide(c, task_id, decision="go", rationale="approved"):
    """POST a decide with a valid CSRF token (the before_request guard requires it)."""
    with c.session_transaction() as sess:
        sess["_csrf_token"] = "testtoken"
    return c.post(
        f"/inception/{task_id}/decide",
        data={"decision": decision, "rationale": rationale, "_csrf_token": "testtoken"},
        headers={"HX-Request": "true"},
    )


def test_htmx_decide_failure_returns_200_not_500(client, monkeypatch):
    c, p = client
    _write_active_task(p, "T-9100", with_decision=False)
    _patch_fw(monkeypatch, "", "ERROR: ## Recommendation section required before decision", False)

    resp = _post_decide(c, "T-9100")
    # Regression guard: a validation rejection must NOT be a server error.
    assert resp.status_code == 200
    assert resp.status_code != 500


def test_htmx_decide_failure_fragment_contains_reason(client, monkeypatch):
    c, p = client
    _write_active_task(p, "T-9100", with_decision=False)
    _patch_fw(monkeypatch, "", "ERROR: ## Recommendation section required before decision", False)

    resp = _post_decide(c, "T-9100")
    html = resp.get_data(as_text=True)
    # Swappable fragment targeting .go-decision, with the reason and the task id.
    assert "go-decision" in html
    assert "Decision not recorded" in html
    assert "Recommendation section required" in html
    assert "T-9100" in html


def test_htmx_decide_success_returns_decision_card(client, monkeypatch):
    c, p = client
    _write_active_task(p, "T-9101", with_decision=True)
    _patch_fw(monkeypatch, "Inception decision recorded", "", True)

    resp = _post_decide(c, "T-9101")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)
    assert "Decision recorded" in html
    assert "GO" in html
