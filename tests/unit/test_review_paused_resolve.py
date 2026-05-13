"""Tests for /review/T-XXX paused-dispatch panel + resolve endpoint.

Origin: T-1810 (dispatch-safety arc — web parity for `fw pause resolve`).
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FRAMEWORK_ROOT))
sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))


# ---------------------------------------------------------------------------
# Helpers — mirror tests/unit/test_pause_resolve.py
# ---------------------------------------------------------------------------


def _make_dispatch(
    dispatch_id: str,
    task_id: str,
    task_type: str,
    outcome: str,
    terminal_event: dict | None = None,
    retry_of: str | None = None,
):
    row = {
        "schema_version": 1,
        "ts": "2026-05-13T17:00:00+00:00",
        "dispatch_id": dispatch_id,
        "task_id": task_id,
        "task_type": task_type,
        "workflow_id": task_type,
        "worker_kind": "TermLink",
        "model": "sonnet",
        "outcome": outcome,
    }
    if terminal_event is not None:
        row["terminal_event"] = terminal_event
    if retry_of is not None:
        row["retry_of_dispatch_id"] = retry_of
    return row


def _setup_project(tmp_path: Path, dispatches: list[dict], task_id: str = "T-9999"):
    wf_dir = tmp_path / ".context" / "project" / "workflows"
    wf_dir.mkdir(parents=True, exist_ok=True)
    (wf_dir / "default.yaml").write_text(
        "task_type: default\n"
        "worker_kind: TermLink\n"
        "model: sonnet\n"
        "effort: medium\n"
        "prompt_template: prompts/default.md\n"
        "allowed_tools: [Read]\n"
        "cost_cap_usd: 1.0\n"
        "cwd: $PROJECT_ROOT\n"
        "allow_pause: true\n"
    )
    (tmp_path / "prompts").mkdir(exist_ok=True)
    (tmp_path / "prompts" / "default.md").write_text(
        "TASK $TASK_ID: $TASK_NAME\n\nACs:\n$ACCEPTANCE_CRITERIA\n"
    )
    # Task file required for resolve_pause → load_task_frontmatter chain.
    (tmp_path / ".tasks" / "active").mkdir(parents=True, exist_ok=True)
    (tmp_path / ".tasks" / "active" / f"{task_id}-test.md").write_text(
        "---\n"
        f"id: {task_id}\n"
        'name: "synthetic"\n'
        "workflow_type: build\n"
        "status: started-work\n"
        "owner: agent\n"
        "horizon: now\n"
        "tags: []\n"
        "created: 2026-05-13T00:00:00Z\n"
        "last_update: 2026-05-13T00:00:00Z\n"
        "---\n\n"
        "## Acceptance Criteria\n\n### Human\n- [ ] [REVIEW] check the thing\n"
    )
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text("\n".join(json.dumps(d) for d in dispatches) + "\n")
    return tmp_path


@pytest.fixture
def synthetic_project(tmp_path, monkeypatch):
    """Reload all modules that bind PROJECT_ROOT at import time."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_PROJECT_ROOT", str(tmp_path))
    for mod in [
        "pause_resolve",
        "dispatch_pause",
        "resolver",
        "workflow_lint",
        "web.shared",
        "web.blueprints.review",
        "web.app",
    ]:
        sys.modules.pop(mod, None)
    return tmp_path


# ---------------------------------------------------------------------------
# Filter helper — list_paused_dispatches_for_task
# ---------------------------------------------------------------------------


def test_filter_returns_only_matching_task(synthetic_project):
    _setup_project(synthetic_project, [
        _make_dispatch("d-9999-a", "T-9999", "default", "paused",
                       terminal_event={"type": "pause_requested", "question": "Q1?"}),
        _make_dispatch("d-other-1", "T-1234", "default", "paused",
                       terminal_event={"type": "pause_requested", "question": "Q2?"}),
        _make_dispatch("d-9999-b", "T-9999", "default", "paused",
                       terminal_event={"type": "pause_requested", "question": "Q3?"}),
    ])
    from dispatch_pause import list_paused_dispatches_for_task

    rows = list_paused_dispatches_for_task("T-9999", synthetic_project)
    ids = {r["dispatch_id"] for r in rows}
    assert ids == {"d-9999-a", "d-9999-b"}


def test_filter_drops_retry_resolved(synthetic_project):
    _setup_project(synthetic_project, [
        _make_dispatch("d-9999-a", "T-9999", "default", "paused",
                       terminal_event={"type": "pause_requested", "question": "Q1?"}),
        _make_dispatch("d-9999-retry", "T-9999", "default", "success",
                       retry_of="d-9999-a"),
        _make_dispatch("d-9999-b", "T-9999", "default", "paused",
                       terminal_event={"type": "pause_requested", "question": "Q2?"}),
    ])
    from dispatch_pause import list_paused_dispatches_for_task

    rows = list_paused_dispatches_for_task("T-9999", synthetic_project)
    ids = {r["dispatch_id"] for r in rows}
    assert ids == {"d-9999-b"}  # d-9999-a deflated by the retry row


def test_filter_empty_task_id(synthetic_project):
    _setup_project(synthetic_project, [])
    from dispatch_pause import list_paused_dispatches_for_task

    assert list_paused_dispatches_for_task("", synthetic_project) == []


def test_filter_no_matches(synthetic_project):
    _setup_project(synthetic_project, [
        _make_dispatch("d-other", "T-1234", "default", "paused",
                       terminal_event={"type": "pause_requested", "question": "?"}),
    ])
    from dispatch_pause import list_paused_dispatches_for_task

    assert list_paused_dispatches_for_task("T-9999", synthetic_project) == []


# ---------------------------------------------------------------------------
# Flask endpoint — uses the real /review handler via app test client
# ---------------------------------------------------------------------------


CSRF_TOKEN = "test-csrf-token-deadbeef"


@pytest.fixture
def app_client(synthetic_project):
    """Boot the Flask app with PROJECT_ROOT pointed at the synthetic tree.

    Seeds a CSRF token in the session so POST tests don't need to GET first.
    """
    from web.app import app

    app.config["TESTING"] = True
    client = app.test_client()
    with client.session_transaction() as sess:
        sess["_csrf_token"] = CSRF_TOKEN
    return client


def _post(client, url, *, data):
    """Helper — POST with CSRF token injected."""
    data = dict(data)
    data["_csrf_token"] = CSRF_TOKEN
    return client.post(url, data=data)


def test_review_page_shows_paused_panel(synthetic_project, app_client):
    _setup_project(synthetic_project, [
        _make_dispatch("d-aaaaaa-bbbb", "T-9999", "default", "paused",
                       terminal_event={
                           "type": "pause_requested",
                           "question": "Should I drop the legacy shim?",
                           "assessment": {"severity": "high", "likelihood": "high"},
                       }),
    ])
    resp = app_client.get("/review/T-9999")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)
    assert "Paused Dispatches" in html
    assert "Should I drop the legacy shim?" in html
    assert "HIGH" in html  # severity badge rendered
    # Form posts to the resolve endpoint with the dispatch_id.
    assert 'action="/review/T-9999/pause/d-aaaaaa-bbbb/resolve"' in html


def test_review_page_no_panel_when_no_paused(synthetic_project, app_client):
    _setup_project(synthetic_project, [
        _make_dispatch("d-success", "T-9999", "default", "success"),
    ])
    resp = app_client.get("/review/T-9999")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)
    assert "Paused Dispatches" not in html


def test_resolve_endpoint_redirects_and_creates_retry(synthetic_project, app_client):
    _setup_project(synthetic_project, [
        _make_dispatch("d-paused-001-x", "T-9999", "default", "paused",
                       terminal_event={
                           "type": "pause_requested",
                           "question": "?",
                           "assessment": {"severity": "high", "likelihood": "high"},
                       }),
    ])
    resp = _post(app_client,
        "/review/T-9999/pause/d-paused-001-x/resolve",
        data={"answer": "Yes — go ahead."},
    )
    # See-other redirect back to /review/T-9999 with ?resolved=...
    assert resp.status_code == 303
    assert "/review/T-9999" in resp.headers["Location"]
    assert "resolved=" in resp.headers["Location"]

    # The retry row landed in dispatches.jsonl with retry_of_dispatch_id set.
    log = (synthetic_project / ".context" / "dispatches.jsonl").read_text()
    rows = [json.loads(line) for line in log.splitlines() if line.strip()]
    retries = [r for r in rows if r.get("retry_of_dispatch_id") == "d-paused-001-x"]
    assert len(retries) == 1
    assert retries[0]["task_id"] == "T-9999"

    # Re-fetching /review/T-9999 should no longer show the paused row.
    resp2 = app_client.get("/review/T-9999")
    assert resp2.status_code == 200
    html2 = resp2.get_data(as_text=True)
    assert "Paused Dispatches" not in html2


def test_resolve_empty_answer_redirects_with_error(synthetic_project, app_client):
    _setup_project(synthetic_project, [
        _make_dispatch("d-paused-002", "T-9999", "default", "paused",
                       terminal_event={"type": "pause_requested", "question": "?"}),
    ])
    resp = _post(app_client,
        "/review/T-9999/pause/d-paused-002/resolve",
        data={"answer": "   "},
    )
    assert resp.status_code == 303
    assert "resolve_error=" in resp.headers["Location"]


def test_resolve_unknown_dispatch_redirects_with_error(synthetic_project, app_client):
    _setup_project(synthetic_project, [
        _make_dispatch("d-paused-003", "T-9999", "default", "paused",
                       terminal_event={"type": "pause_requested", "question": "?"}),
    ])
    resp = _post(app_client,
        "/review/T-9999/pause/does-not-exist-xx/resolve",
        data={"answer": "anything"},
    )
    assert resp.status_code == 303
    loc = resp.headers["Location"]
    assert "resolve_error=" in loc
    assert "not%20found" in loc or "not+found" in loc


def test_resolve_non_paused_redirects_with_error(synthetic_project, app_client):
    _setup_project(synthetic_project, [
        _make_dispatch("d-success-1x", "T-9999", "default", "success"),
    ])
    resp = _post(app_client,
        "/review/T-9999/pause/d-success-1x/resolve",
        data={"answer": "anything"},
    )
    assert resp.status_code == 303
    assert "resolve_error=" in resp.headers["Location"]
