"""T-1799: /orchestrator surfaces Workflow coverage panel.

Pins the pure helper ``_workflow_coverage()`` and the rendered HTML.
Mirrors ``lib.workflow_coverage.check_workflow_dispatcher_coverage`` shape;
graceful when helper not importable.
"""

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture
def client(tmp_path, monkeypatch):
    (tmp_path / ".context" / "project" / "workflows").mkdir(parents=True)
    (tmp_path / ".context" / "arcs").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".context" / "audits").mkdir(parents=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    # lib symlink so the web helper can import workflow_coverage from PROJECT_ROOT/lib
    (tmp_path / "lib").symlink_to(REPO_ROOT / "lib")

    runtime = tmp_path / "tlrun"
    runtime.mkdir()

    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("TERMLINK_RUNTIME_DIR", str(runtime))

    # Refresh PROJECT_ROOT-derived constants. T-1996: use importlib.reload (reuses
    # the existing module object) instead of `del sys.modules[...]` — the latter
    # REPLACES web.shared, orphaning every other test module's import-time
    # `from web.shared import …` bindings. That desynced test_project_root_discovery's
    # G-069 test from `patch("web.shared.FRAMEWORK_ROOT")` (it patched the new module
    # while the test called a function bound to the old one). reload keeps identity.
    import importlib
    import web.shared
    import web.blueprints.orchestrator
    import web.app
    importlib.reload(web.shared)
    importlib.reload(web.blueprints.orchestrator)
    importlib.reload(web.app)
    if "workflow_coverage" in sys.modules:
        importlib.reload(sys.modules["workflow_coverage"])

    app = web.app.create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c, tmp_path


def _write_workflow(tmp_path, name, worker_kind=None, provider=None):
    wf_dir = tmp_path / ".context" / "project" / "workflows"
    body = f"name: {name}\n"
    if worker_kind is not None:
        body += f"worker_kind: {worker_kind}\n"
    if provider is not None:
        body += f"provider: {provider}\n"
    (wf_dir / f"{name}.yaml").write_text(body)


# ─── helper shape ────────────────────────────────────────────────────────────


def test_workflow_coverage_returns_helper_shape(client):
    c, tmp_path = client
    _write_workflow(tmp_path, "wf-pi", "pi", provider="anthropic")
    _write_workflow(tmp_path, "wf-tl", "TermLink")

    from web.blueprints.orchestrator import _workflow_coverage
    r = _workflow_coverage()
    assert r["available"] is True
    assert r["ok"] is True
    names = sorted(w["name"] for w in r["workflows"])
    assert names == ["wf-pi", "wf-tl"]


def test_workflow_coverage_flags_unroutable(client):
    c, tmp_path = client
    _write_workflow(tmp_path, "wf-task", "Task")  # declarable but unroutable

    from web.blueprints.orchestrator import _workflow_coverage
    r = _workflow_coverage()
    assert r["ok"] is False
    assert len(r["unroutable_workflows"]) == 1
    assert r["unroutable_workflows"][0]["worker_kind"] == "Task"


# ─── route-level rendering ───────────────────────────────────────────────────


def test_panel_renders_with_workflows(client):
    c, tmp_path = client
    _write_workflow(tmp_path, "wf-pi", "pi", provider="anthropic")
    _write_workflow(tmp_path, "wf-ollama", "ollama-loop")
    # T-1803: seed recent dispatches so the panel renders OK, not WARN.
    # (Workflows never dispatched are stale by default → WARN.)
    import datetime, json as _json
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    dispatches = tmp_path / ".context" / "dispatches.jsonl"
    dispatches.write_text(
        _json.dumps({"workflow_id": "wf-pi", "ts": now, "task_id": "T-X"}) + "\n" +
        _json.dumps({"workflow_id": "wf-ollama", "ts": now, "task_id": "T-Y"}) + "\n"
    )

    rv = c.get("/orchestrator")
    assert rv.status_code == 200
    html = rv.data.decode()
    assert "Workflow coverage" in html
    assert "wf-pi" in html
    assert "wf-ollama" in html
    # Routable dispatcher footer
    assert "Routable dispatchers" in html
    # OK badge when all route AND no stale
    assert "OK" in html


def test_panel_renders_warn_when_unroutable(client):
    c, tmp_path = client
    _write_workflow(tmp_path, "wf-pi", "pi", provider="anthropic")
    _write_workflow(tmp_path, "wf-task", "Task")

    rv = c.get("/orchestrator")
    assert rv.status_code == 200
    html = rv.data.decode()
    assert "Workflow coverage" in html
    assert "wf-task" in html
    # FAIL badge appears when any workflow is unroutable
    assert "FAIL" in html
    assert "declare an unroutable worker_kind" in html


def test_panel_shows_workflow_without_worker_kind_as_interactive(client):
    c, tmp_path = client
    _write_workflow(tmp_path, "wf-interactive", None)

    rv = c.get("/orchestrator")
    html = rv.data.decode()
    assert "wf-interactive" in html
    assert "interactive" in html  # the "— (interactive)" cell label


def test_panel_shows_declarable_but_unroutable_set(client):
    """The footer line surfaces VALID_WORKER_KINDS - _DISPATCHERS.keys()."""
    c, tmp_path = client
    _write_workflow(tmp_path, "wf-pi", "pi", provider="anthropic")  # any routable workflow

    rv = c.get("/orchestrator")
    html = rv.data.decode()
    assert "Declarable but unroutable" in html
    # Today the set is {Task}; the test asserts the label is there but
    # doesn't hardcode Task — if the set changes, the label still renders.


# ─── T-1801: provider column + missing-provider class ───────────────────────


def test_panel_renders_provider_column(client):
    """4th column header `provider` exists; pi rows render provider value;
    non-pi rows render `—` (em-dash for empty)."""
    c, tmp_path = client
    _write_workflow(tmp_path, "wf-pi", "pi", provider="anthropic")
    _write_workflow(tmp_path, "wf-ollama", "ollama-loop")  # no provider — fine

    rv = c.get("/orchestrator")
    assert rv.status_code == 200
    html = rv.data.decode()
    # 4th column header
    assert "<th>provider</th>" in html
    # pi row shows provider value
    assert "anthropic" in html
    # non-pi rows still render (look for ollama-loop name; the empty cell
    # contains an em-dash inside <span class="muted">)
    assert "wf-ollama" in html


def test_panel_renders_warn_state_when_only_stale(client):
    """T-1803: all workflows route but one never dispatched → WARN badge."""
    c, tmp_path = client
    _write_workflow(tmp_path, "wf-cold", "ollama-loop")  # never dispatched

    rv = c.get("/orchestrator")
    assert rv.status_code == 200
    html = rv.data.decode()
    # WARN badge (between OK and FAIL semantically) appears
    assert "WARN" in html
    # Stale workflow named in the WARN message
    assert "stale" in html
    # Row gets a `stale` marker
    assert "wf-cold" in html


def test_panel_renders_last_dispatched_column(client):
    """T-1802: 5th column `Last dispatched` exists; dispatched workflows
    show ISO date + task link; never-dispatched workflows show `never`."""
    c, tmp_path = client
    _write_workflow(tmp_path, "wf-fired", "pi", provider="anthropic")
    _write_workflow(tmp_path, "wf-cold", "ollama-loop")

    # Seed dispatches.jsonl with one record for wf-fired only
    import json as _json
    dispatches = tmp_path / ".context" / "dispatches.jsonl"
    dispatches.write_text(_json.dumps({
        "workflow_id": "wf-fired",
        "ts": "2026-05-10T11:22:33+00:00",
        "task_id": "T-9999",
    }) + "\n")

    rv = c.get("/orchestrator")
    assert rv.status_code == 200
    html = rv.data.decode()
    # 5th column header
    assert "<th>Last dispatched</th>" in html
    # Fired workflow renders ISO date prefix
    assert "2026-05-10" in html
    # Task link rendered
    assert 'href="/tasks/T-9999"' in html
    # Cold workflow renders `never`
    assert "never" in html


def test_panel_flags_pi_missing_provider(client):
    """Pi workflow without provider → FAIL badge + missing-provider footer
    line + row-level warn marker."""
    c, tmp_path = client
    _write_workflow(tmp_path, "wf-pi-bad", "pi")  # missing provider

    rv = c.get("/orchestrator")
    assert rv.status_code == 200
    html = rv.data.decode()
    # FAIL state (ok=False ANDs both classes)
    assert "FAIL" in html
    # Footer line surfaces missing-provider names
    assert "Missing provider" in html
    assert "wf-pi-bad" in html
    # Row-level warn marker for pi-without-provider (cell contains "missing"
    # badge — distinguishable from a non-pi empty cell which shows `—`)
    assert "missing" in html
    # Status line mentions the missing-provider class
    assert "pi workflow(s) missing provider" in html
