"""T-1662 — /arcs and /arcs/<id> routes (Phase 2 of T-1653).

Pins the generic per-arc surface page introduced after T-1661 shipped the
Arc system MVP. /orchestrator stays as the orchestrator-arc-specific
drill-down; /arcs is the generalization.

Tests use Flask test_client against an isolated PROJECT_ROOT.
"""

import json
import os
from pathlib import Path

import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture
def client(tmp_path, monkeypatch):
    # Seed minimal PROJECT_ROOT
    (tmp_path / ".context" / "arcs").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")

    # Point PROJECT_ROOT before importing web modules
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    # Force reimport so PROJECT_ROOT is re-evaluated
    import importlib
    import web.shared
    import web.blueprints.arcs
    importlib.reload(web.shared)
    importlib.reload(web.blueprints.arcs)
    import web.app
    importlib.reload(web.app)
    app = web.app.create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c, tmp_path


def _write_arc(p, arc_id, status="in-progress", tasks=None, anchor="T-9001", decision=None, name=None):
    arcs_dir = p / ".context" / "arcs"
    arcs_dir.mkdir(parents=True, exist_ok=True)
    body = {
        "id": arc_id,
        "name": name or f"{arc_id} arc",
        "description": f"description of {arc_id}",
        "status": status,
        "anchor_task": anchor,
        "constituent_tasks": tasks or [],
        "created": "2026-05-01T00:00:00Z",
        "closed_at": None,
        "decision": decision,
    }
    (arcs_dir / f"{arc_id}.yaml").write_text(yaml.safe_dump(body))


def _write_task(p, tid, status="started-work", workflow="build"):
    sub = "completed" if status == "work-completed" else "active"
    (p / ".tasks" / sub / f"{tid}-name.md").write_text(
        f"---\nid: {tid}\nname: {tid} task\nstatus: {status}\n"
        f"workflow_type: {workflow}\nhorizon: now\n---\n"
    )


def test_arcs_index_empty(client):
    c, p = client
    resp = c.get("/arcs")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "No arcs registered" in body
    assert "fw arc create" in body


def test_arcs_index_lists_registered_arc(client):
    c, p = client
    _write_arc(p, "demo", tasks=["T-1", "T-2"])
    _write_task(p, "T-1", "work-completed")
    _write_task(p, "T-2", "started-work")
    resp = c.get("/arcs")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "demo" in body
    assert "/arcs/demo" in body
    assert "2 constituent" in body or "2 task" in body or "2&nbsp;constituent" in body


def test_arc_detail_renders_constituents_and_completion_check(client):
    c, p = client
    _write_arc(p, "demo", tasks=["T-1", "T-2"])
    _write_task(p, "T-1", "work-completed")
    _write_task(p, "T-2", "started-work")
    resp = c.get("/arcs/demo")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    # Constituents render with status badges
    assert "T-1" in body
    assert "T-2" in body
    assert "work-completed" in body
    # Three-question completion check appears (in-progress arcs only)
    assert "Arc Completion Discipline" in body
    assert "wire-level observation" in body or "fresh substrate" in body
    # fw arc close snippet appears for in-progress arc
    assert "fw arc close demo" in body


def test_arc_detail_closed_arc_omits_completion_check(client):
    c, p = client
    _write_arc(p, "shipped", status="closed", decision="success", tasks=["T-1"])
    _write_task(p, "T-1", "work-completed")
    resp = c.get("/arcs/shipped")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    # Closed arcs show decision, not the completion check
    assert "Arc closed" in body
    assert "success" in body
    # And NO fw arc close hint (already closed)
    assert "fw arc close shipped" not in body


def test_arc_detail_404_for_unregistered(client):
    c, p = client
    resp = c.get("/arcs/no-such-arc")
    assert resp.status_code == 404


def test_arc_detail_handles_missing_constituent_task_file(client):
    """Constituent task in YAML but no .md file — render with 'missing' tag."""
    c, p = client
    _write_arc(p, "demo", tasks=["T-1", "T-9999"])
    _write_task(p, "T-1", "started-work")
    # T-9999 has no task file
    resp = c.get("/arcs/demo")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "T-9999" in body
    assert "task file not found" in body or "missing" in body.lower()
