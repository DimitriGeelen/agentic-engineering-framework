"""T-1774: Unit tests for `fw resolver run` CLI integration.

Pins:
  - happy path: cmd_run returns 0 on success
  - worker error: cmd_run returns 2 on terminal error
  - NotImplementedError from spawn → cmd_run returns 1 with stderr message
  - SpawnError → cmd_run returns 1 with stderr message
  - --json flag emits parseable JSON
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

import resolver  # noqa: E402


def _args(json_flag=False):
    return argparse.Namespace(
        task_id="T-1773",
        task_type="cheap-research",
        json=json_flag,
        var=[],
    )


def _envelope():
    return {
        "dispatch_id": "abc-123",
        "task_id": "T-1773",
        "task_type": "cheap-research",
        "worker_kind": "pi",
        "model": "claude-3-5-sonnet-latest",
        "effort": "medium",
        "prompt": "hello",
        "allowed_tools": [],
        "cost_cap_usd": 0.0,
        "cwd": "/tmp",
        "env": {},
        "blob_dir": "/tmp/blob",
        "variant_id": None,
    }


def _outcome(status="success", terminal=None):
    return {
        "status": status,
        "events_count": 3,
        "events_path": "/tmp/blob/events.jsonl",
        "terminal_event": terminal or {"type": "agent.done"},
    }


@patch.object(resolver, "load_task_frontmatter", return_value={})
@patch.object(resolver, "resolve")
def test_cmd_run_success_returns_0(mock_resolve, _mock_frontmatter, capsys):
    mock_resolve.return_value = (_envelope(), {})
    fake_spawn = MagicMock()
    fake_spawn.spawn_dispatch.return_value = _outcome()
    fake_spawn.SpawnError = type("SpawnError", (Exception,), {})
    with patch.dict(sys.modules, {"spawn": fake_spawn}):
        rc = resolver.cmd_run(_args())
    assert rc == 0
    out = capsys.readouterr().out
    assert "status:         success" in out
    assert "worker_kind:    pi" in out


@patch.object(resolver, "load_task_frontmatter", return_value={})
@patch.object(resolver, "resolve")
def test_cmd_run_worker_error_returns_2(mock_resolve, _mock_frontmatter, capsys):
    mock_resolve.return_value = (_envelope(), {})
    fake_spawn = MagicMock()
    fake_spawn.spawn_dispatch.return_value = _outcome(
        status="error",
        terminal={"type": "error", "retryable": True, "message": "429"},
    )
    fake_spawn.SpawnError = type("SpawnError", (Exception,), {})
    with patch.dict(sys.modules, {"spawn": fake_spawn}):
        rc = resolver.cmd_run(_args())
    assert rc == 2
    out = capsys.readouterr().out
    assert "status:         error" in out
    assert "terminal:       error" in out


@patch.object(resolver, "load_task_frontmatter", return_value={})
@patch.object(resolver, "resolve")
def test_cmd_run_notimplemented_returns_1(mock_resolve, _mock_frontmatter, capsys):
    mock_resolve.return_value = (_envelope(), {})
    fake_spawn = MagicMock()
    fake_spawn.spawn_dispatch.side_effect = NotImplementedError(
        "spawn driver: worker_kind='ollama-loop' not yet routed (T-1773 v1 ...)"
    )
    fake_spawn.SpawnError = type("SpawnError", (Exception,), {})
    with patch.dict(sys.modules, {"spawn": fake_spawn}):
        rc = resolver.cmd_run(_args())
    assert rc == 1
    err = capsys.readouterr().err
    assert "ollama-loop" in err
    assert "T-1773" in err


@patch.object(resolver, "load_task_frontmatter", return_value={})
@patch.object(resolver, "resolve")
def test_cmd_run_spawnerror_returns_1(mock_resolve, _mock_frontmatter, capsys):
    mock_resolve.return_value = (_envelope(), {})
    fake_spawn = MagicMock()
    SpawnError = type("SpawnError", (Exception,), {})
    fake_spawn.SpawnError = SpawnError
    fake_spawn.spawn_dispatch.side_effect = SpawnError("provider missing")
    with patch.dict(sys.modules, {"spawn": fake_spawn}):
        rc = resolver.cmd_run(_args())
    assert rc == 1
    err = capsys.readouterr().err
    assert "provider missing" in err


@patch.object(resolver, "load_task_frontmatter", return_value={})
@patch.object(resolver, "resolve")
def test_cmd_run_json_flag_emits_parseable_json(mock_resolve, _mock_frontmatter, capsys):
    mock_resolve.return_value = (_envelope(), {})
    fake_spawn = MagicMock()
    fake_spawn.spawn_dispatch.return_value = _outcome()
    fake_spawn.SpawnError = type("SpawnError", (Exception,), {})
    with patch.dict(sys.modules, {"spawn": fake_spawn}):
        rc = resolver.cmd_run(_args(json_flag=True))
    assert rc == 0
    parsed = json.loads(capsys.readouterr().out)
    assert parsed["status"] == "success"
    assert parsed["events_count"] == 3


@patch.object(resolver, "load_task_frontmatter", return_value={})
@patch.object(resolver, "resolve")
def test_cmd_run_resolver_error_returns_1(mock_resolve, _mock_frontmatter, capsys):
    mock_resolve.side_effect = resolver.ResolverError("no workflow for cheap-research")
    rc = resolver.cmd_run(_args())
    assert rc == 1
    err = capsys.readouterr().err
    assert "no workflow" in err


def test_cmd_run_var_invalid_returns_1(capsys):
    args = argparse.Namespace(
        task_id="T-1773",
        task_type="cheap-research",
        json=False,
        var=["NO_EQUALS_HERE"],
    )
    with patch.object(resolver, "load_task_frontmatter", return_value={}):
        rc = resolver.cmd_run(args)
    assert rc == 1
    err = capsys.readouterr().err
    assert "must be KEY=VALUE" in err
