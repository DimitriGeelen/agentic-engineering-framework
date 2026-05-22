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


def _write_task(p, tid, status="started-work", workflow="build", tags=None):
    sub = "completed" if status == "work-completed" else "active"
    tags_yaml = ""
    if tags:
        tags_yaml = "tags: [" + ", ".join(tags) + "]\n"
    (p / ".tasks" / sub / f"{tid}-name.md").write_text(
        f"---\nid: {tid}\nname: {tid} task\nstatus: {status}\n"
        f"workflow_type: {workflow}\nhorizon: now\n{tags_yaml}---\n"
    )


def test_arcs_index_empty(client):
    # T-1904 made kanban the default /arcs view; the "No arcs registered"
    # empty-state guidance lives in the flat-list view (?view=list). Hit that
    # view to assert the create-your-first-arc guidance still renders. (T-1997.)
    c, p = client
    resp = c.get("/arcs?view=list")
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


def test_arc_detail_renders_arc_keyed_reports(client):
    """docs/reports/<arc_id>-*.md files surface as Reports & evidence section."""
    c, p = client
    _write_arc(p, "demo")
    reports_dir = p / "docs" / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    (reports_dir / "demo-closure-readiness.md").write_text("# Closure readiness\n")
    (reports_dir / "demo-q1-evidence.md").write_text("# Q1 evidence\n")
    # Also a non-matching file that must NOT appear:
    (reports_dir / "T-9999-unrelated.md").write_text("# unrelated\n")
    resp = c.get("/arcs/demo")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "Reports &amp; evidence" in body
    assert "demo-closure-readiness" in body
    assert "demo-q1-evidence" in body
    # Each report is a /file/ link
    assert "/file/docs/reports/demo-closure-readiness.md" in body
    # Unrelated reports stay out
    assert "T-9999-unrelated" not in body


def test_arc_detail_omits_reports_section_when_none(client):
    """No matching arc-keyed reports → section is not rendered."""
    c, p = client
    _write_arc(p, "demo")
    resp = c.get("/arcs/demo")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "Reports &amp; evidence" not in body


# ───────────── T-1817: merge constituent_tasks ∪ arc-tag scan ─────────────


def test_resolve_constituents_merges_tag_scan(client):
    """T-1817: tasks tagged arc:<id> appear alongside YAML constituent_tasks.

    Mirrors the data-source-drift fix T-1813 applied to agents/audit/audit.sh.
    The /arcs detail page must reflect arc:<id> tag scan, not just the
    denormalised constituent_tasks cache (which misses tag-only additions).
    """
    c, p = client
    # Legacy: constituent_tasks lists T-1
    _write_arc(p, "demo", tasks=["T-1"])
    _write_task(p, "T-1", "work-completed")
    # T-2 and T-3 are NOT in constituent_tasks but ARE tagged arc:demo
    _write_task(p, "T-2", "work-completed", tags=["arc:demo"])
    _write_task(p, "T-3", "started-work", tags=["arc:demo", "other-tag"])
    # T-4 is tagged with a different arc — must NOT appear
    _write_task(p, "T-4", "started-work", tags=["arc:other"])

    resp = c.get("/arcs/demo")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    # Use /tasks/T-X href as the constituent-row marker (avoids matching
    # incidental T-NNN references in JS helpers / other page chrome).
    assert "/tasks/T-1" in body, "legacy constituent missing"
    assert "/tasks/T-2" in body, "tag-scan addition missing (data-source drift)"
    assert "/tasks/T-3" in body, "tag-scan addition missing (data-source drift)"
    assert "/tasks/T-4" not in body, "wrong-arc tagged task leaked into detail page"


def test_resolve_constituents_dedupes_legacy_and_tagged(client):
    """T-1817: a task that's both in constituent_tasks AND tagged appears once."""
    c, p = client
    _write_arc(p, "demo", tasks=["T-1"])
    _write_task(p, "T-1", "work-completed", tags=["arc:demo"])
    resp = c.get("/arcs/demo")
    body = resp.get_data(as_text=True)
    # T-1 should appear once in the constituents table, not duplicated.
    # The table uses one row per constituent containing the id text in a link.
    # Use the /tasks/T-1 href as the row marker (one per constituent).
    assert body.count("/tasks/T-1") == 1, "duplicate constituent rendered"


def test_list_arcs_task_count_uses_merged_source(client):
    """T-1817: index page task_count reflects merged source-of-truth.

    Legacy bug: with constituent_tasks=['T-1'] and 5 tag-only additions, the
    index page would say '1 task' while the detail page (post-fix) shows 6.
    Both surfaces must agree.
    """
    c, p = client
    _write_arc(p, "demo", tasks=["T-1"])
    _write_task(p, "T-1", "work-completed")
    for n in ("T-2", "T-3", "T-4", "T-5", "T-6"):
        _write_task(p, n, "work-completed", tags=["arc:demo"])
    resp = c.get("/arcs")
    body = resp.get_data(as_text=True)
    # Six total: 1 legacy + 5 tag-only, no overlap
    assert "6 constituent" in body or "6 task" in body or "6&nbsp;constituent" in body, \
        f"expected merged count of 6, body excerpt: {body[body.find('demo'):body.find('demo')+400]}"
