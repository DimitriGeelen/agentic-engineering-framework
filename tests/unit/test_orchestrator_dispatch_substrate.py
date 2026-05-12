"""T-1792 — /orchestrator surfaces dispatch substrate (by_model breakdown).

Pins both the pure helper `_dispatch_substrate()` and the rendered HTML
for the new panel. CLI parity with `fw orchestrator status` (T-1788).
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


def _seed_dispatches(project_root: Path, rows: list[dict]) -> Path:
    path = project_root / ".context" / "dispatches.jsonl"
    path.write_text("\n".join(json.dumps(r) for r in rows) + "\n")
    return path


# ─── Pure function: _dispatch_substrate ──────────────────────────────────────


def test_substrate_unavailable_when_no_jsonl(client):
    c, _ = client
    from web.blueprints.orchestrator import _dispatch_substrate
    out = _dispatch_substrate()
    assert out["available"] is False
    assert out["total"] == 0
    assert out["by_model"] == []


def test_substrate_returns_totals_and_by_model_when_jsonl_present(client):
    c, tmp_path = client
    _seed_dispatches(tmp_path, [
        {"dispatch_id": "a", "task_id": "T-1", "model": "haiku"},
        {"dispatch_id": "b", "task_id": "T-2", "model": "haiku"},
        {"dispatch_id": "c", "task_id": "T-3", "model": "opus"},
    ])
    from web.blueprints.orchestrator import _dispatch_substrate
    out = _dispatch_substrate()
    assert out["available"] is True
    assert out["total"] == 3
    assert out["synthetic_total"] == 0
    # Sorted count desc — haiku (2) before opus (1).
    assert out["by_model"] == [
        {"model": "haiku", "count": 2},
        {"model": "opus", "count": 1},
    ]


def test_substrate_excludes_synthetic_t_stress_rows(client):
    c, tmp_path = client
    _seed_dispatches(tmp_path, [
        {"dispatch_id": "a", "task_id": "T-1", "model": "haiku"},
        {"dispatch_id": "b", "task_id": "T-stress-0", "model": "haiku"},
        {"dispatch_id": "c", "task_id": "T-stress-1", "model": "opus"},
        {"dispatch_id": "d", "task_id": "T-2", "model": "opus"},
    ])
    from web.blueprints.orchestrator import _dispatch_substrate
    out = _dispatch_substrate()
    assert out["total"] == 2  # only T-1, T-2
    assert out["synthetic_total"] == 2
    # by_model reflects only real rows.
    assert out["by_model"] == [
        {"model": "haiku", "count": 1},
        {"model": "opus", "count": 1},
    ]


def test_substrate_excludes_rows_missing_model_from_by_model(client):
    c, tmp_path = client
    _seed_dispatches(tmp_path, [
        {"dispatch_id": "a", "task_id": "T-1", "model": "haiku"},
        {"dispatch_id": "b", "task_id": "T-2"},  # no model field
        {"dispatch_id": "c", "task_id": "T-3", "model": None},  # explicit null
    ])
    from web.blueprints.orchestrator import _dispatch_substrate
    out = _dispatch_substrate()
    # Total counts ALL real rows (model missing is fine).
    assert out["total"] == 3
    # but by_model only counts rows with a model value.
    assert out["by_model"] == [{"model": "haiku", "count": 1}]


def test_substrate_graceful_on_malformed_jsonl_line(client):
    c, tmp_path = client
    path = tmp_path / ".context" / "dispatches.jsonl"
    path.write_text(
        json.dumps({"dispatch_id": "a", "task_id": "T-1", "model": "haiku"}) + "\n"
        + "this is not json {{\n"
        + json.dumps({"dispatch_id": "b", "task_id": "T-2", "model": "opus"}) + "\n"
    )
    from web.blueprints.orchestrator import _dispatch_substrate
    out = _dispatch_substrate()
    # Malformed line is skipped; surrounding rows parsed.
    assert out["total"] == 2
    assert out["by_model"] == [
        {"model": "haiku", "count": 1},
        {"model": "opus", "count": 1},
    ]


def test_substrate_by_model_sorted_count_desc(client):
    c, tmp_path = client
    _seed_dispatches(tmp_path, [
        {"dispatch_id": str(i), "task_id": f"T-{i}", "model": "haiku"}
        for i in range(5)
    ] + [
        {"dispatch_id": str(i + 100), "task_id": f"T-{i + 100}", "model": "opus"}
        for i in range(3)
    ] + [
        {"dispatch_id": str(i + 200), "task_id": f"T-{i + 200}", "model": "sonnet"}
        for i in range(1)
    ])
    from web.blueprints.orchestrator import _dispatch_substrate
    out = _dispatch_substrate()
    counts = [r["count"] for r in out["by_model"]]
    assert counts == sorted(counts, reverse=True)
    assert out["by_model"][0]["model"] == "haiku"  # 5 — top
    assert out["by_model"][-1]["model"] == "sonnet"  # 1 — bottom


# ─── Route-level: GET /orchestrator renders the panel ────────────────────────


def test_orchestrator_page_renders_substrate_panel_when_present(client):
    c, tmp_path = client
    _seed_dispatches(tmp_path, [
        {"dispatch_id": "a", "task_id": "T-1", "model": "haiku"},
        {"dispatch_id": "b", "task_id": "T-2", "model": "haiku"},
        {"dispatch_id": "c", "task_id": "T-3", "model": "opus"},
    ])
    rv = c.get("/orchestrator")
    assert rv.status_code == 200
    html = rv.data.decode()
    assert "Dispatch substrate" in html
    assert "haiku" in html
    assert "opus" in html


def test_orchestrator_page_shows_substrate_absent_when_no_jsonl(client):
    c, _ = client
    rv = c.get("/orchestrator")
    assert rv.status_code == 200
    html = rv.data.decode()
    assert "Dispatch substrate" in html
    assert "substrate absent" in html


# ─── T-1794: by_task_type companion breakdown ────────────────────────────────


def test_substrate_returns_by_task_type(client):
    c, tmp_path = client
    _seed_dispatches(tmp_path, [
        {"dispatch_id": "a", "task_id": "T-1", "task_type": "build", "model": "haiku"},
        {"dispatch_id": "b", "task_id": "T-2", "task_type": "build", "model": "haiku"},
        {"dispatch_id": "c", "task_id": "T-3", "task_type": "design", "model": "opus"},
    ])
    from web.blueprints.orchestrator import _dispatch_substrate
    out = _dispatch_substrate()
    assert out["by_task_type"] == [
        {"task_type": "build", "count": 2},
        {"task_type": "design", "count": 1},
    ]


def test_substrate_by_task_type_excludes_synthetic(client):
    c, tmp_path = client
    _seed_dispatches(tmp_path, [
        {"dispatch_id": "a", "task_id": "T-1", "task_type": "build", "model": "haiku"},
        {"dispatch_id": "b", "task_id": "T-stress-0", "task_type": "build",
         "model": "haiku"},
        {"dispatch_id": "c", "task_id": "T-stress-1", "task_type": "design",
         "model": "opus"},
    ])
    from web.blueprints.orchestrator import _dispatch_substrate
    out = _dispatch_substrate()
    # Synthetic rows excluded from by_task_type the same way they're
    # excluded from by_model and total.
    assert out["by_task_type"] == [{"task_type": "build", "count": 1}]


def test_substrate_by_task_type_excludes_rows_missing_task_type(client):
    c, tmp_path = client
    _seed_dispatches(tmp_path, [
        {"dispatch_id": "a", "task_id": "T-1", "task_type": "build", "model": "haiku"},
        {"dispatch_id": "b", "task_id": "T-2", "model": "opus"},  # no task_type
        {"dispatch_id": "c", "task_id": "T-3", "task_type": None, "model": "opus"},
    ])
    from web.blueprints.orchestrator import _dispatch_substrate
    out = _dispatch_substrate()
    # Total counts ALL real rows; by_task_type only those with the field.
    assert out["total"] == 3
    assert out["by_task_type"] == [{"task_type": "build", "count": 1}]


def test_substrate_by_task_type_sorted_count_desc(client):
    c, tmp_path = client
    _seed_dispatches(tmp_path, [
        {"dispatch_id": str(i), "task_id": f"T-{i}", "task_type": "build",
         "model": "haiku"}
        for i in range(4)
    ] + [
        {"dispatch_id": str(i + 100), "task_id": f"T-{i + 100}",
         "task_type": "design", "model": "opus"}
        for i in range(2)
    ] + [
        {"dispatch_id": str(i + 200), "task_id": f"T-{i + 200}",
         "task_type": "spike", "model": "sonnet"}
        for i in range(1)
    ])
    from web.blueprints.orchestrator import _dispatch_substrate
    out = _dispatch_substrate()
    counts = [r["count"] for r in out["by_task_type"]]
    assert counts == sorted(counts, reverse=True)
    assert out["by_task_type"][0]["task_type"] == "build"
    assert out["by_task_type"][-1]["task_type"] == "spike"


def test_orchestrator_page_renders_by_task_type_subtable(client):
    c, tmp_path = client
    _seed_dispatches(tmp_path, [
        {"dispatch_id": "a", "task_id": "T-1", "task_type": "escalation-triage",
         "model": "haiku"},
        {"dispatch_id": "b", "task_id": "T-2", "task_type": "build",
         "model": "opus"},
    ])
    rv = c.get("/orchestrator")
    assert rv.status_code == 200
    html = rv.data.decode()
    assert "By task-type" in html
    assert "escalation-triage" in html
    assert "build" in html
