"""T-1669 Step 3 — /orchestrator surfaces learned per-task-type prefs.

Pins `_route_cache_learned` (pure function) and the rendered HTML output
of /orchestrator when route-cache.json is seeded with model_stats.
The learned-routing panel is the user-visible half of the
orchestrator-rethink arc's headline_mechanic ("operator observes the
routing decision live on /orchestrator and watches per-task-type model
preferences shift as the route_cache learns").
"""

import json
import os
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
        yield c, runtime


def _seed_cache(runtime_dir, model_stats):
    cache = {"entries": {}, "model_stats": model_stats}
    (runtime_dir / "route-cache.json").write_text(json.dumps(cache))


# ─── Pure function: _route_cache_learned ─────────────────────────────────────

def test_learned_returns_unavailable_when_no_cache(client):
    c, _ = client
    from web.blueprints.orchestrator import _route_cache_learned
    out = _route_cache_learned()
    assert out["available"] is False
    assert out["by_task_type"] == []
    assert out["total_stats"] == 0


def test_learned_returns_empty_when_cache_has_no_stats(client):
    c, runtime = client
    _seed_cache(runtime, {})
    from web.blueprints.orchestrator import _route_cache_learned
    out = _route_cache_learned()
    assert out["available"] is True
    assert out["by_task_type"] == []
    assert out["total_stats"] == 0


def test_learned_picks_best_per_task_type(client):
    c, runtime = client
    _seed_cache(runtime, {
        "haiku:build":  {"model":"haiku","task_type":"build","successes":8,"failures":2,"last_used":"2026-05-02T10:00:00Z"},
        "opus:build":   {"model":"opus","task_type":"build","successes":3,"failures":7,"last_used":"2026-05-02T10:00:00Z"},
        "sonnet:design": {"model":"sonnet","task_type":"design","successes":5,"failures":0,"last_used":"2026-05-02T10:00:00Z"},
    })
    from web.blueprints.orchestrator import _route_cache_learned
    out = _route_cache_learned()
    assert out["available"] is True
    rows = {r["task_type"]: r for r in out["by_task_type"]}
    assert rows["build"]["best"]["model"] == "haiku"
    assert rows["build"]["best"]["rate"] == 0.8
    assert rows["design"]["best"]["model"] == "sonnet"
    assert rows["design"]["best"]["rate"] == 1.0
    # All candidates surfaced for build:
    assert len(rows["build"]["candidates"]) == 2
    assert {c["model"] for c in rows["build"]["candidates"]} == {"haiku", "opus"}


def test_learned_skips_zero_volume_stats(client):
    c, runtime = client
    _seed_cache(runtime, {
        "haiku:build": {"model":"haiku","task_type":"build","successes":0,"failures":0,"last_used":None},
        "opus:build":  {"model":"opus","task_type":"build","successes":2,"failures":1,"last_used":None},
    })
    from web.blueprints.orchestrator import _route_cache_learned
    out = _route_cache_learned()
    rows = {r["task_type"]: r for r in out["by_task_type"]}
    # haiku had 0 total → excluded; opus is the only candidate
    assert len(rows["build"]["candidates"]) == 1
    assert rows["build"]["best"]["model"] == "opus"


def test_learned_handles_corrupt_cache_gracefully(client):
    c, runtime = client
    (runtime / "route-cache.json").write_text("not json {")
    from web.blueprints.orchestrator import _route_cache_learned
    out = _route_cache_learned()
    assert out["available"] is False
    assert out["by_task_type"] == []


# ─── Route-level: GET /orchestrator renders the panel ────────────────────────

def test_orchestrator_page_renders_learned_panel_when_cache_present(client):
    c, runtime = client
    _seed_cache(runtime, {
        "haiku:build": {"model":"haiku","task_type":"build","successes":6,"failures":1,"last_used":"2026-05-02T10:00:00Z"},
    })
    resp = c.get("/orchestrator")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    # Panel header present:
    assert "Learned routing" in body
    # Best model rendered:
    assert "haiku" in body
    # Volume rendered:
    assert "6/7" in body or "(6/7)" in body
    # No "cache absent" badge when stats exist:
    assert "cache absent" not in body


def test_orchestrator_page_shows_cache_absent_when_no_file(client):
    c, runtime = client
    # Don't seed cache
    resp = c.get("/orchestrator")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "Learned routing" in body
    assert "cache absent" in body


def test_orchestrator_page_shows_no_recordings_when_cache_empty(client):
    c, runtime = client
    _seed_cache(runtime, {})
    resp = c.get("/orchestrator")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "Learned routing" in body
    assert "no recordings" in body


def test_orchestrator_page_renders_multiple_task_types(client):
    c, runtime = client
    _seed_cache(runtime, {
        "haiku:build":   {"model":"haiku","task_type":"build","successes":8,"failures":2,"last_used":"2026-05-02T10:00:00Z"},
        "sonnet:design": {"model":"sonnet","task_type":"design","successes":4,"failures":1,"last_used":"2026-05-02T10:00:00Z"},
    })
    resp = c.get("/orchestrator")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    # Both task-types appear:
    assert "build" in body
    assert "design" in body
    assert "haiku" in body
    assert "sonnet" in body
