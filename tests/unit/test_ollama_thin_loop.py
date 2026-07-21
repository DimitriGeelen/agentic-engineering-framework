"""T-2592: Unit tests for OllamaThinLoopWorker (mocked HTTP).

Pins:
  - module import performs no network I/O
  - prompt() yields init/user/assistant events in claude -p stream-json shape
  - end_turn → terminal result is_error=False with final text
  - tool_use round-trip: tool executed, tool_result posted, loop continues
  - iteration cap → terminal result is_error=True
  - HTTP error → terminal result is_error=True (no raise)
  - allowed_tools filters the catalogue; init event lists the filtered set
  - Bash deny-list and path sandbox refuse escapes
  - env overlay beats os.environ for base URL resolution
  - prompt() is single-shot
"""

from __future__ import annotations

import json
import sys
import urllib.error
from pathlib import Path
from unittest.mock import patch

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

import ollama_thin_loop  # noqa: E402
from ollama_thin_loop import OllamaThinLoopWorker  # noqa: E402


def _resp(content, stop_reason, usage=None):
    return {
        "content": content,
        "stop_reason": stop_reason,
        "usage": usage or {"input_tokens": 10, "output_tokens": 5},
    }


def _run(responses, tmp_path, **kwargs):
    """Drive a worker whose _post_messages returns the queued responses."""
    captured_bodies = []

    def fake_post(self, body):  # noqa: ARG001
        # deep-snapshot: the worker mutates its messages list in place after
        # the request, and body holds a reference to it
        captured_bodies.append(json.loads(json.dumps(body)))
        if not responses:
            raise AssertionError("worker requested more turns than scripted")
        return responses.pop(0)

    with patch.object(OllamaThinLoopWorker, "_post_messages", fake_post):
        w = OllamaThinLoopWorker(
            model=kwargs.pop("model", "claude-3-5-sonnet-hermes3"),
            cwd=kwargs.pop("cwd", str(tmp_path)),
            **kwargs,
        )
        events = list(w.prompt(kwargs.get("message", "probe")))
    return w, events, captured_bodies


def test_end_turn_yields_clean_result(tmp_path):
    responses = [_resp([{"type": "text", "text": "the answer"}], "end_turn")]
    _, events, _ = _run(responses, tmp_path)
    types = [e["type"] for e in events]
    assert types == ["system", "user", "assistant", "result"]
    assert events[0]["subtype"] == "init"
    assert events[-1]["is_error"] is False
    assert events[-1]["result"] == "the answer"


def test_tool_use_round_trip_executes_and_continues(tmp_path):
    (tmp_path / "hello.txt").write_text("hello from disk")
    responses = [
        _resp([{"type": "tool_use", "id": "tu_1", "name": "Read",
                "input": {"path": "hello.txt"}}], "tool_use"),
        _resp([{"type": "text", "text": "done"}], "end_turn"),
    ]
    _, events, bodies = _run(responses, tmp_path)
    # init, user(prompt), assistant(tool_use), user(tool_result), assistant, result
    types = [e["type"] for e in events]
    assert types == ["system", "user", "assistant", "user", "assistant", "result"]
    tool_result = events[3]["message"]["content"][0]
    assert tool_result["type"] == "tool_result"
    assert tool_result["tool_use_id"] == "tu_1"
    assert "hello from disk" in tool_result["content"]
    # second request carried the tool_result back to the model
    assert bodies[1]["messages"][-1]["content"][0]["type"] == "tool_result"
    assert events[-1]["is_error"] is False


def test_iteration_cap_is_error(tmp_path):
    responses = [
        _resp([{"type": "tool_use", "id": f"tu_{i}", "name": "Bash",
                "input": {"command": "echo hi"}}], "tool_use")
        for i in range(2)
    ]
    _, events, _ = _run(responses, tmp_path, max_iter=2)
    assert events[-1]["type"] == "result"
    assert events[-1]["is_error"] is True
    assert events[-1]["iterations"] == 2


def test_http_error_yields_error_result_not_raise(tmp_path):
    def fake_post(self, body):  # noqa: ARG001
        raise urllib.error.URLError("connection refused")

    with patch.object(OllamaThinLoopWorker, "_post_messages", fake_post):
        w = OllamaThinLoopWorker("m", str(tmp_path))
        events = list(w.prompt("probe"))
    assert events[-1]["type"] == "result"
    assert events[-1]["is_error"] is True
    assert "Request failed" in events[-1]["result"]


def test_allowed_tools_filters_catalogue(tmp_path):
    responses = [_resp([{"type": "text", "text": "ok"}], "end_turn")]
    _, events, bodies = _run(responses, tmp_path, allowed_tools=["Bash"])
    assert events[0]["tools"] == ["Bash"]
    assert [t["name"] for t in bodies[0]["tools"]] == ["Bash"]


def test_unknown_tool_returns_error_result_block(tmp_path):
    responses = [
        _resp([{"type": "tool_use", "id": "tu_x", "name": "Write",
                "input": {"path": "x", "content": "y"}}], "tool_use"),
        _resp([{"type": "text", "text": "ok"}], "end_turn"),
    ]
    _, events, _ = _run(responses, tmp_path)
    tool_result = events[3]["message"]["content"][0]
    assert "unknown tool 'Write'" in tool_result["content"]


def test_bash_deny_list_blocks(tmp_path):
    w = OllamaThinLoopWorker("m", str(tmp_path))
    out = w._tool_bash({"command": "sudo rm -rf /"})
    assert out.startswith("ERROR: command blocked")


def test_path_sandbox_refuses_escape(tmp_path):
    w = OllamaThinLoopWorker("m", str(tmp_path))
    out = w._tool_read({"path": "/root/.ssh/id_rsa"})
    assert "outside sandbox" in out


def test_env_overlay_beats_os_environ(tmp_path, monkeypatch):
    monkeypatch.setenv("ANTHROPIC_BASE_URL", "http://from-os:1")
    w = OllamaThinLoopWorker("m", str(tmp_path),
                             env={"ANTHROPIC_BASE_URL": "http://overlay:2"})
    assert w._env("ANTHROPIC_BASE_URL", "d") == "http://overlay:2"
    w2 = OllamaThinLoopWorker("m", str(tmp_path))
    assert w2._env("ANTHROPIC_BASE_URL", "d") == "http://from-os:1"


def test_prompt_is_single_shot(tmp_path):
    responses = [_resp([{"type": "text", "text": "ok"}], "end_turn")]
    w, _, _ = _run(responses, tmp_path)
    with pytest.raises(RuntimeError):
        list(w.prompt("again"))


def test_events_are_json_serializable(tmp_path):
    responses = [
        _resp([{"type": "tool_use", "id": "tu_1", "name": "Grep",
                "input": {"pattern": "x", "path": "."}}], "tool_use"),
        _resp([{"type": "text", "text": "ok"}], "end_turn"),
    ]
    _, events, _ = _run(responses, tmp_path)
    for e in events:
        json.dumps(e)


def test_spawn_dispatcher_registered():
    sys.path.insert(0, str(ROOT / "lib"))
    import spawn  # noqa: PLC0415
    assert "ollama-thin-loop" in spawn._DISPATCHERS
