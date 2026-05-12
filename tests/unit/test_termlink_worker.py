"""T-1797: Unit tests for lib/termlink_worker.py.

Pins:
  - dispatch argv shape (task_id, name, model, env, tools, project, timeout)
  - prompt() yields events parsed from result.jsonl
  - prompt() terminates on type=result event
  - close() is idempotent and safe when never launched
  - context-manager protocol
  - re-prompt raises RuntimeError (single-shot semantics)
  - malformed result.jsonl lines skipped

Subprocess.Popen is monkeypatched — no live `fw termlink dispatch` invocation.
"""

from __future__ import annotations

import json
import sys
import subprocess
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))


@pytest.fixture
def worker_factory(tmp_path, monkeypatch):
    """Return a factory that builds TermLinkWorker with DISPATCH_DIR redirected
    to tmp_path. Each call gets a fresh worker name + worker dir."""
    if "termlink_worker" in sys.modules:
        del sys.modules["termlink_worker"]
    import termlink_worker  # noqa: E402
    monkeypatch.setattr(termlink_worker, "DISPATCH_DIR", tmp_path)

    def _factory(name="tl-test", **kwargs):
        defaults = dict(
            model="claude-sonnet-4-5",
            cwd=str(tmp_path),
            task_id="T-1797",
            fw_bin="/usr/bin/true",
            name=name,
        )
        defaults.update(kwargs)
        w = termlink_worker.TermLinkWorker(**defaults)
        # Force wdir to match the monkeypatched DISPATCH_DIR (use the
        # worker's resolved name in case the caller passed None).
        w.wdir = tmp_path / w.name
        return w

    return _factory, tmp_path, termlink_worker


# ─── argv shape ──────────────────────────────────────────────────────────────


def test_dispatch_argv_includes_required_flags(worker_factory):
    factory, _, _ = worker_factory
    w = factory(name="tl-argv")
    argv = w._build_dispatch_argv("hello world")
    assert "termlink" in argv and "dispatch" in argv
    assert "--task" in argv and "T-1797" in argv
    assert "--name" in argv and "tl-argv" in argv
    assert "--prompt" in argv and "hello world" in argv
    assert "--project" in argv
    assert "--timeout" in argv
    assert "--model" in argv and "claude-sonnet-4-5" in argv


def test_dispatch_argv_includes_optional_flags(worker_factory):
    factory, _, _ = worker_factory
    w = factory(
        env={"ANTHROPIC_BASE_URL": "http://localhost:4000",
             "ANTHROPIC_API_KEY": "sk-abc"},
        allowed_tools=["Read", "Bash", "Grep"],
        task_type="ollama-research",
    )
    argv = w._build_dispatch_argv("msg")
    # tools forwarded as comma-joined
    assert "--tools" in argv
    assert "Read,Bash,Grep" in argv
    # env forwarded as repeated KEY=VAL
    env_pairs = [argv[i + 1] for i, a in enumerate(argv) if a == "--env"]
    assert "ANTHROPIC_BASE_URL=http://localhost:4000" in env_pairs
    assert "ANTHROPIC_API_KEY=sk-abc" in env_pairs
    # task_type forwarded
    assert "--task-type" in argv
    assert "ollama-research" in argv


def test_dispatch_argv_omits_flags_when_empty(worker_factory):
    factory, _, _ = worker_factory
    w = factory(model="", allowed_tools=[], env=None, task_type=None)
    argv = w._build_dispatch_argv("msg")
    assert "--model" not in argv
    assert "--tools" not in argv
    assert "--env" not in argv
    assert "--task-type" not in argv


def test_wait_argv_shape(worker_factory):
    factory, _, _ = worker_factory
    w = factory(name="tl-wait", timeout=600)
    argv = w._build_wait_argv()
    assert argv[1:3] == ["termlink", "wait"]
    assert "--name" in argv and "tl-wait" in argv
    assert "--timeout" in argv and "600" in argv


# ─── prompt() flow ───────────────────────────────────────────────────────────


def _stub_dispatch_success(monkeypatch, result_path: Path, events: list):
    """Wire Popen + subprocess.run so dispatch+wait succeed and result.jsonl
    is populated with `events`."""
    result_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.write_text("\n".join(json.dumps(e) for e in events) + "\n")

    fake_proc = MagicMock()
    fake_proc.wait.return_value = 0
    fake_proc.stderr.read.return_value = ""
    monkeypatch.setattr(subprocess, "Popen", MagicMock(return_value=fake_proc))
    monkeypatch.setattr(subprocess, "run", MagicMock(return_value=MagicMock(returncode=0)))


def test_prompt_yields_events_until_result(worker_factory, monkeypatch):
    factory, tmp_path, _ = worker_factory
    w = factory(name="tl-yield")
    events = [
        {"type": "system", "subtype": "init"},
        {"type": "assistant", "message": {"content": "hi"}},
        {"type": "result", "is_error": False, "result": "done"},
    ]
    _stub_dispatch_success(monkeypatch, w.wdir / "result.jsonl", events)

    collected = list(w.prompt("test"))
    assert len(collected) == 3
    assert collected[-1]["type"] == "result"


def test_prompt_terminates_on_result_skipping_trailing(worker_factory, monkeypatch):
    """Events after the terminal result event must NOT be yielded."""
    factory, _, _ = worker_factory
    w = factory(name="tl-term")
    events = [
        {"type": "assistant", "message": {}},
        {"type": "result", "is_error": False},
        {"type": "trailing", "should": "be ignored"},
    ]
    _stub_dispatch_success(monkeypatch, w.wdir / "result.jsonl", events)

    collected = list(w.prompt("test"))
    assert len(collected) == 2
    assert collected[-1]["type"] == "result"


def test_prompt_skips_malformed_lines(worker_factory, monkeypatch):
    factory, _, _ = worker_factory
    w = factory(name="tl-malformed")
    w.wdir.mkdir(parents=True, exist_ok=True)
    (w.wdir / "result.jsonl").write_text(
        '{"type":"assistant"}\n'
        'not-json-garbage\n'
        '\n'
        '{"type":"result","is_error":false}\n'
    )

    fake_proc = MagicMock()
    fake_proc.wait.return_value = 0
    monkeypatch.setattr(subprocess, "Popen", MagicMock(return_value=fake_proc))
    monkeypatch.setattr(subprocess, "run", MagicMock())

    collected = list(w.prompt("test"))
    assert len(collected) == 2
    assert collected[0]["type"] == "assistant"
    assert collected[1]["type"] == "result"


def test_prompt_raises_when_dispatch_fails(worker_factory, monkeypatch):
    factory, _, _ = worker_factory
    w = factory(name="tl-dispatch-fail")
    fake_proc = MagicMock()
    fake_proc.wait.return_value = 1
    fake_proc.stderr.read.return_value = "Missing --name"
    monkeypatch.setattr(subprocess, "Popen", MagicMock(return_value=fake_proc))

    with pytest.raises(RuntimeError) as exc:
        list(w.prompt("test"))
    assert "fw termlink dispatch failed" in str(exc.value)


def test_prompt_handles_missing_result_jsonl(worker_factory, monkeypatch):
    """When result.jsonl never lands (worker crashed pre-write), prompt()
    yields nothing rather than crashing."""
    factory, _, _ = worker_factory
    w = factory(name="tl-missing")
    fake_proc = MagicMock()
    fake_proc.wait.return_value = 0
    monkeypatch.setattr(subprocess, "Popen", MagicMock(return_value=fake_proc))
    monkeypatch.setattr(subprocess, "run", MagicMock())

    collected = list(w.prompt("test"))
    assert collected == []


def test_prompt_single_shot(worker_factory, monkeypatch):
    factory, _, _ = worker_factory
    w = factory(name="tl-single")
    _stub_dispatch_success(
        monkeypatch, w.wdir / "result.jsonl",
        [{"type": "result", "is_error": False}],
    )
    list(w.prompt("first"))
    with pytest.raises(RuntimeError) as exc:
        list(w.prompt("second"))
    assert "single-shot" in str(exc.value)


# ─── lifecycle / context manager ─────────────────────────────────────────────


def test_close_safe_when_never_launched(worker_factory):
    factory, _, _ = worker_factory
    w = factory()
    assert w.close() == 0
    # Calling again is also fine.
    assert w.close() == 0


def test_context_manager_invokes_close(worker_factory, monkeypatch):
    factory, _, _ = worker_factory
    w = factory(name="tl-ctx")
    _stub_dispatch_success(
        monkeypatch, w.wdir / "result.jsonl",
        [{"type": "result", "is_error": False}],
    )
    with w as worker:
        list(worker.prompt("test"))
    # After __exit__, proc reaped → close returns 0 on subsequent call
    assert w.proc is None


def test_default_name_unique(worker_factory):
    """When no name is supplied, defaults are unique per instance."""
    factory, _, _ = worker_factory
    a = factory(name=None)
    b = factory(name=None)
    assert a.name != b.name
    assert a.name.startswith("tl-")
    assert b.name.startswith("tl-")
