"""T-2342 (arc-011 M1 §5) — /orchestrator/parallel view.

Pins both the pure helper `_in_flight_dispatches()` and the rendered HTML
for the new view. Sibling to test_orchestrator_dispatch_substrate.py.

Scenarios per AC #4:
  - empty dispatches.jsonl → renders "No dispatches"
  - one in-flight row → renders one card with dispatch_id
  - row with outcome="success" → not rendered
  - multiple in-flight + completed → only in-flight shown
"""

import json
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture
def client(tmp_path, monkeypatch):
    (tmp_path / ".context" / "arcs").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".context" / "audits").mkdir(parents=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")

    runtime = tmp_path / "tlrun"
    runtime.mkdir()

    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("TERMLINK_RUNTIME_DIR", str(runtime))

    import importlib
    import web.shared
    import web.blueprints.orchestrator
    importlib.reload(web.shared)
    importlib.reload(web.blueprints.orchestrator)
    import web.app
    importlib.reload(web.app)
    app = web.app.create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c, tmp_path


def _seed(project_root: Path, rows: list[dict]) -> Path:
    path = project_root / ".context" / "dispatches.jsonl"
    path.write_text("\n".join(json.dumps(r) for r in rows) + "\n")
    return path


# ─── Pure function: _in_flight_dispatches ────────────────────────────────────


def test_in_flight_returns_empty_when_no_jsonl(client):
    c, _ = client
    from web.blueprints.orchestrator import _in_flight_dispatches
    assert _in_flight_dispatches() == []


def test_in_flight_returns_empty_for_completed_only(client):
    c, root = client
    _seed(root, [
        {"dispatch_id": "D-1", "task_id": "T-A", "outcome": "success"},
        {"dispatch_id": "D-2", "task_id": "T-B", "outcome": "failure"},
    ])
    from web.blueprints.orchestrator import _in_flight_dispatches
    assert _in_flight_dispatches() == []


def test_in_flight_returns_one_row(client):
    c, root = client
    _seed(root, [
        {"dispatch_id": "D-1", "task_id": "T-A", "outcome": ""},
    ])
    from web.blueprints.orchestrator import _in_flight_dispatches
    rows = _in_flight_dispatches()
    assert len(rows) == 1
    assert rows[0]["dispatch_id"] == "D-1"
    assert rows[0]["task_id"] == "T-A"


def test_in_flight_dedups_by_dispatch_id_latest_wins(client):
    """A dispatch_id appearing twice: start row (outcome="") then end row
    (outcome="success") should NOT be in-flight — the latest row wins."""
    c, root = client
    _seed(root, [
        {"dispatch_id": "D-1", "task_id": "T-A", "outcome": "", "started_at": 100},
        {"dispatch_id": "D-1", "task_id": "T-A", "outcome": "success", "completed_at": 101},
    ])
    from web.blueprints.orchestrator import _in_flight_dispatches
    # The second row supersedes the first; D-1 is now complete, not in-flight
    assert _in_flight_dispatches() == []


def test_in_flight_mixed_completed_and_inflight(client):
    c, root = client
    _seed(root, [
        {"dispatch_id": "D-1", "task_id": "T-A", "outcome": "", "started_at": 100},
        {"dispatch_id": "D-2", "task_id": "T-B", "outcome": "success"},
        {"dispatch_id": "D-3", "task_id": "T-C", "outcome": "", "started_at": 200},
    ])
    from web.blueprints.orchestrator import _in_flight_dispatches
    rows = _in_flight_dispatches()
    ids = sorted(r["dispatch_id"] for r in rows)
    assert ids == ["D-1", "D-3"]


def test_in_flight_handles_malformed_lines(client):
    """Malformed JSON lines must be skipped, not crash the page."""
    c, root = client
    path = root / ".context" / "dispatches.jsonl"
    path.write_text(
        '{"dispatch_id":"D-1","task_id":"T-A","outcome":""}\n'
        'not-json-at-all\n'
        '{"dispatch_id":"D-2","task_id":"T-B","outcome":""}\n'
        '\n'  # blank line
    )
    from web.blueprints.orchestrator import _in_flight_dispatches
    rows = _in_flight_dispatches()
    ids = sorted(r["dispatch_id"] for r in rows)
    assert ids == ["D-1", "D-2"]


# ─── HTTP view: /orchestrator/parallel ───────────────────────────────────────


def test_view_renders_empty_state_when_no_dispatches(client):
    c, _ = client
    resp = c.get("/orchestrator/parallel")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "No dispatches in flight" in body
    assert "0" in body  # in_flight_count


def test_view_renders_card_for_in_flight_row(client):
    c, root = client
    _seed(root, [
        {"dispatch_id": "D-DEMO-001", "task_id": "T-DEMO-A", "outcome": "", "started_at": 100},
    ])
    resp = c.get("/orchestrator/parallel")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "D-DEMO-001" in body
    assert "T-DEMO-A" in body
    assert "No dispatches in flight" not in body


def test_view_only_renders_in_flight_rows(client):
    """Completed dispatches must NOT appear as cards."""
    c, root = client
    _seed(root, [
        {"dispatch_id": "D-OLD", "task_id": "T-PAST", "outcome": "success"},
        {"dispatch_id": "D-NEW", "task_id": "T-NOW", "outcome": "", "started_at": 100},
    ])
    resp = c.get("/orchestrator/parallel")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "D-NEW" in body
    assert "T-NOW" in body
    # The completed dispatch's id and task should not render as cards
    # (T-PAST appearing in the body would be a bug)
    assert "T-PAST" not in body


def test_view_renders_htmx_auto_refresh_trigger(client):
    """The page must include the hx-trigger every 2s so it auto-refreshes."""
    c, _ = client
    resp = c.get("/orchestrator/parallel")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert 'hx-trigger="every 2s"' in body
    assert 'hx-get="/orchestrator/parallel"' in body


def test_existing_orchestrator_route_still_works(client):
    """Regression: adding /orchestrator/parallel must not break /orchestrator."""
    c, _ = client
    resp = c.get("/orchestrator")
    assert resp.status_code == 200
