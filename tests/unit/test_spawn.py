"""T-1773: Unit tests for lib/spawn.py.

Pins:
  - pi route streams events to <blob_dir>/events.jsonl
  - terminal agent.done → outcome success
  - terminal error → outcome error
  - other worker_kinds raise NotImplementedError with deferral message
  - update_outcome_row rewrites matching row atomically
  - update_outcome_row returns False when dispatch_id absent

Mocked PiWorker — no live pi binary needed.
"""

from __future__ import annotations

import json
import sys
import os
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))


@pytest.fixture
def tmp_project(tmp_path, monkeypatch):
    """Set PROJECT_ROOT to a tmp dir and force-reload spawn so the module
    picks up the override (its constants are computed at import time)."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    (tmp_path / ".context").mkdir()
    (tmp_path / ".context" / "project" / "workflows").mkdir(parents=True)
    # Force-reload spawn so PROJECT_ROOT-derived constants reflect the tmp dir
    if "spawn" in sys.modules:
        del sys.modules["spawn"]
    import spawn  # noqa: E402 — force fresh import per fixture
    return tmp_path, spawn


def _envelope(tmp_path, **overrides):
    blob = tmp_path / ".context" / "dispatch-blobs" / "2026-05" / "abc-123"
    base = {
        "dispatch_id": "abc-123",
        "task_id": "T-1773",
        "task_type": "cheap-research",
        "worker_kind": "pi",
        "model": "claude-3-5-sonnet-latest",
        "effort": "medium",
        "prompt": "hello world",
        "allowed_tools": ["Read"],
        "cost_cap_usd": 0.0,
        "cwd": str(tmp_path),
        "env": {},
        "blob_dir": str(blob),
        "variant_id": None,
    }
    base.update(overrides)
    return base


def _fake_pi_worker(events):
    """Return a factory that mimics PiWorker(...) → instance with
    .prompt() yielding events and .close() returning 0."""
    def factory(*a, **kw):  # noqa: ARG001
        m = MagicMock()
        m.prompt.return_value = iter(events)
        m.close.return_value = 0
        return m
    return factory


def _write_workflow(tmp_path, task_type="cheap-research", provider="anthropic"):
    wf = tmp_path / ".context" / "project" / "workflows" / f"{task_type}.yaml"
    wf.write_text(
        f"task_type: {task_type}\nworker_kind: pi\n"
        f"provider: {provider}\nmodel: claude-3-5-sonnet-latest\n"
    )


def test_pi_route_success(tmp_project):
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path)
    env = _envelope(tmp_path)
    events = [
        {"type": "response", "id": "req-1"},
        {"type": "tool_use", "tool": "read"},
        {"type": "agent.done"},
    ]
    with patch.object(spawn, "_DISPATCHERS", {"pi": spawn._spawn_pi}):
        with patch("pi_worker.PiWorker", _fake_pi_worker(events)):
            result = spawn.spawn_dispatch(env)

    assert result["status"] == "success"
    assert result["events_count"] == 3
    assert result["terminal_event"]["type"] == "agent.done"
    # events.jsonl exists with all events
    ep = Path(result["events_path"])
    assert ep.exists()
    lines = ep.read_text().strip().splitlines()
    assert len(lines) == 3
    assert json.loads(lines[-1])["type"] == "agent.done"


def test_pi_route_error_terminal(tmp_project):
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path)
    env = _envelope(tmp_path)
    events = [
        {"type": "response", "id": "req-1"},
        {"type": "error", "retryable": True, "message": "429"},
    ]
    with patch("pi_worker.PiWorker", _fake_pi_worker(events)):
        result = spawn.spawn_dispatch(env)
    assert result["status"] == "error"
    assert result["terminal_event"]["retryable"] is True


def test_other_worker_kinds_raise_notimplemented(tmp_project):
    """T-1775 added ollama-loop. TermLink + Task remain deferred."""
    tmp_path, spawn = tmp_project
    for wk in ("TermLink", "Task"):
        env = _envelope(tmp_path, worker_kind=wk)
        with pytest.raises(NotImplementedError) as exc:
            spawn.spawn_dispatch(env)
        msg = str(exc.value)
        assert wk in msg
        # Deferral message references the originating task IDs
        assert "T-1773" in msg or "T-1775" in msg


def test_ollama_loop_route_success(tmp_project):
    """T-1775: ollama-loop route streams events; type=result is_error=False → success."""
    tmp_path, spawn = tmp_project
    env = _envelope(
        tmp_path,
        worker_kind="ollama-loop",
        env={"ANTHROPIC_BASE_URL": "http://localhost:4000"},
    )
    events = [
        {"type": "system", "subtype": "init"},
        {"type": "assistant", "message": {"content": "hi"}},
        {"type": "result", "is_error": False, "result": "done"},
    ]

    def fake_factory(**kwargs):
        m = MagicMock()
        m.prompt.return_value = iter(events)
        m.close.return_value = 0
        return m

    import ollama_loop  # noqa: F401 — ensure module is in sys.modules
    with patch("ollama_loop.OllamaLoopWorker", side_effect=fake_factory):
        result = spawn.spawn_dispatch(env)

    assert result["status"] == "success"
    assert result["events_count"] == 3
    assert result["terminal_event"]["type"] == "result"
    assert result["terminal_event"]["is_error"] is False
    ep = Path(result["events_path"])
    assert ep.exists()
    lines = ep.read_text().strip().splitlines()
    assert len(lines) == 3


def test_ollama_loop_route_error_terminal(tmp_project):
    """T-1775: type=result is_error=True → status=error."""
    tmp_path, spawn = tmp_project
    env = _envelope(tmp_path, worker_kind="ollama-loop")
    events = [
        {"type": "assistant", "message": {}},
        {"type": "result", "is_error": True, "error": "model timeout"},
    ]

    def fake_factory(**kwargs):
        m = MagicMock()
        m.prompt.return_value = iter(events)
        m.close.return_value = 0
        return m

    with patch("ollama_loop.OllamaLoopWorker", side_effect=fake_factory):
        result = spawn.spawn_dispatch(env)
    assert result["status"] == "error"
    assert result["terminal_event"]["is_error"] is True


def test_ollama_loop_route_passes_env_and_tools(tmp_project):
    """T-1775: envelope env + allowed_tools forwarded to OllamaLoopWorker."""
    tmp_path, spawn = tmp_project
    env = _envelope(
        tmp_path,
        worker_kind="ollama-loop",
        env={"ANTHROPIC_BASE_URL": "http://localhost:4000",
             "ANTHROPIC_API_KEY": "sk-litellm-local-dev"},
        allowed_tools=["Read", "Bash", "Grep"],
    )
    captured = {}

    def fake_factory(**kwargs):
        captured.update(kwargs)
        m = MagicMock()
        m.prompt.return_value = iter([{"type": "result", "is_error": False}])
        m.close.return_value = 0
        return m

    with patch("ollama_loop.OllamaLoopWorker", side_effect=fake_factory):
        spawn.spawn_dispatch(env)

    assert captured["env"]["ANTHROPIC_BASE_URL"] == "http://localhost:4000"
    assert captured["env"]["ANTHROPIC_API_KEY"] == "sk-litellm-local-dev"
    assert captured["allowed_tools"] == ["Read", "Bash", "Grep"]
    assert captured["model"] == env["model"]


def test_unknown_worker_kind_raises_spawnerror(tmp_project):
    tmp_path, spawn = tmp_project
    env = _envelope(tmp_path, worker_kind="frobnicate")
    with pytest.raises(spawn.SpawnError):
        spawn.spawn_dispatch(env)


def test_update_outcome_row_rewrites_match(tmp_project):
    tmp_path, spawn = tmp_project
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(
        json.dumps({"dispatch_id": "row-1", "outcome": "pending"}) + "\n"
        + json.dumps({"dispatch_id": "row-2", "outcome": "pending"}) + "\n"
        + json.dumps({"dispatch_id": "row-3", "outcome": "pending"}) + "\n"
    )
    ok = spawn.update_outcome_row("row-2", "success", {"events_count": 7})
    assert ok is True
    rows = [json.loads(line) for line in log.read_text().strip().splitlines()]
    outcomes = {r["dispatch_id"]: r["outcome"] for r in rows}
    assert outcomes == {"row-1": "pending", "row-2": "success", "row-3": "pending"}
    by_id = {r["dispatch_id"]: r for r in rows}
    assert by_id["row-2"]["events_count"] == 7


def test_update_outcome_row_no_match_returns_false(tmp_project):
    tmp_path, spawn = tmp_project
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(json.dumps({"dispatch_id": "row-1", "outcome": "pending"}) + "\n")
    ok = spawn.update_outcome_row("missing-id", "success", None)
    assert ok is False
    # File unchanged
    rows = [json.loads(line) for line in log.read_text().strip().splitlines()]
    assert rows[0]["outcome"] == "pending"


def test_update_outcome_row_no_log_returns_false(tmp_project):
    tmp_path, spawn = tmp_project
    # No dispatches.jsonl at all
    ok = spawn.update_outcome_row("any-id", "success", None)
    assert ok is False


def test_update_outcome_row_empty_dispatch_id_returns_false(tmp_project):
    tmp_path, spawn = tmp_project
    (tmp_path / ".context" / "dispatches.jsonl").write_text("")
    ok = spawn.update_outcome_row("", "success", None)
    assert ok is False


def test_module_imports_without_pi_on_path():
    """spawn.py must import without invoking subprocess. PiWorker import is
    deferred to the pi handler."""
    if "spawn" in sys.modules:
        del sys.modules["spawn"]
    import spawn  # noqa: F401
    assert hasattr(spawn, "spawn_dispatch")
    assert hasattr(spawn, "update_outcome_row")
    assert hasattr(spawn, "SpawnError")


def test_pi_route_uses_envelope_provider_when_present(tmp_project):
    tmp_path, spawn = tmp_project
    # No workflow file — must fall back to envelope.provider
    env = _envelope(tmp_path, provider="openai")
    captured = {}
    def factory(*a, **kw):
        captured["provider"] = kw.get("provider") or (a[0] if a else None)
        m = MagicMock()
        m.prompt.return_value = iter([{"type": "agent.done"}])
        m.close.return_value = 0
        return m
    with patch("pi_worker.PiWorker", factory):
        spawn.spawn_dispatch(env)
    assert captured["provider"] == "openai"


def test_pi_route_falls_back_to_workflow_provider(tmp_project):
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path, provider="anthropic")
    env = _envelope(tmp_path)  # no provider in envelope
    captured = {}
    def factory(*a, **kw):
        captured["provider"] = kw.get("provider") or (a[0] if a else None)
        m = MagicMock()
        m.prompt.return_value = iter([{"type": "agent.done"}])
        m.close.return_value = 0
        return m
    with patch("pi_worker.PiWorker", factory):
        spawn.spawn_dispatch(env)
    assert captured["provider"] == "anthropic"


def test_pi_route_missing_provider_raises_spawnerror(tmp_project):
    tmp_path, spawn = tmp_project
    # No workflow file, no envelope provider → must error
    env = _envelope(tmp_path)
    with patch("pi_worker.PiWorker", _fake_pi_worker([{"type": "agent.done"}])):
        with pytest.raises(spawn.SpawnError) as exc:
            spawn.spawn_dispatch(env)
    assert "provider" in str(exc.value)


def test_spawn_dispatch_finalises_outcome_row(tmp_project):
    tmp_path, spawn = tmp_project
    _write_workflow(tmp_path)
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.write_text(json.dumps({"dispatch_id": "abc-123", "outcome": "pending"}) + "\n")
    env = _envelope(tmp_path)
    with patch("pi_worker.PiWorker", _fake_pi_worker([{"type": "agent.done"}])):
        spawn.spawn_dispatch(env)
    rows = [json.loads(line) for line in log.read_text().strip().splitlines()]
    assert rows[0]["outcome"] == "success"
    assert rows[0]["events_count"] == 1
