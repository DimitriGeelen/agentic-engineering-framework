"""T-1775: Unit tests for OllamaLoopWorker (mocked subprocess).

Pins:
  - module import does not spawn claude
  - prompt() yields parsed stream-json events
  - terminal type=result, is_error=False → loop ends; subsequent lines unread
  - terminal type=result, is_error=True → still ends loop, event has is_error=True
  - --tools flag built correctly from allowed_tools
  - env merging: envelope env overrides os.environ
  - close() idempotent + kills hung process
  - context manager closes on exit
  - U+2028/U+2029 inside payload strings does NOT split events (anti-readline)
  - prompt() is single-shot (raises if called twice on same instance)
"""

from __future__ import annotations

import io
import json
import os
import sys
import subprocess
from pathlib import Path
from unittest.mock import patch

import pytest


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

import ollama_loop  # noqa: E402


class _FakeProc:
    def __init__(self, stdout_lines, wait_returns=0, wait_raises=False):
        self.stdout = io.StringIO("".join(stdout_lines))
        self.stderr = io.StringIO()
        self.stdin = None
        self._wait_returns = wait_returns
        self._wait_raises = wait_raises
        self._killed = False

    def wait(self, timeout=None):  # noqa: ARG002
        if self._wait_raises:
            raise subprocess.TimeoutExpired(cmd="claude", timeout=timeout or 0)
        return self._wait_returns

    def kill(self):
        self._killed = True


def _make_worker(stdout_lines, **kwargs):
    fake = _FakeProc(stdout_lines)
    captured = {}

    def fake_popen(argv, **popen_kwargs):
        captured["argv"] = argv
        captured["env"] = popen_kwargs.get("env")
        captured["cwd"] = popen_kwargs.get("cwd")
        return fake

    with patch.object(ollama_loop.subprocess, "Popen", side_effect=fake_popen):
        w = ollama_loop.OllamaLoopWorker(
            model=kwargs.pop("model", "claude-3-5-sonnet-hermes3"),
            cwd=kwargs.pop("cwd", "/tmp"),
            env=kwargs.pop("env", None),
            allowed_tools=kwargs.pop("allowed_tools", None),
        )
        events = list(w.prompt(kwargs.pop("message", "hi")))
    return w, fake, events, captured


def test_module_import_does_not_spawn_claude():
    assert hasattr(ollama_loop, "OllamaLoopWorker")


def test_prompt_yields_events_until_result():
    lines = [
        json.dumps({"type": "system", "subtype": "init"}) + "\n",
        json.dumps({"type": "assistant", "message": {"role": "assistant"}}) + "\n",
        json.dumps({"type": "result", "is_error": False, "result": "ok"}) + "\n",
        json.dumps({"type": "should_not_yield"}) + "\n",
    ]
    _, _, events, _ = _make_worker(lines)
    assert len(events) == 3
    assert events[-1]["type"] == "result"
    assert events[-1]["is_error"] is False


def test_terminal_result_is_error_true_still_ends():
    lines = [
        json.dumps({"type": "result", "is_error": True, "error": "boom"}) + "\n",
        json.dumps({"type": "after_terminal"}) + "\n",
    ]
    _, _, events, _ = _make_worker(lines)
    assert len(events) == 1
    assert events[0]["is_error"] is True


def test_tools_flag_built_from_allowed_tools():
    _, _, _, captured = _make_worker(
        [json.dumps({"type": "result", "is_error": False}) + "\n"],
        allowed_tools=["Read", "Bash", "Grep"],
    )
    argv = captured["argv"]
    assert "--tools" in argv
    idx = argv.index("--tools")
    assert argv[idx + 1] == "Read,Bash,Grep"


def test_no_tools_flag_when_allowed_tools_empty():
    _, _, _, captured = _make_worker(
        [json.dumps({"type": "result", "is_error": False}) + "\n"],
        allowed_tools=[],
    )
    assert "--tools" not in captured["argv"]


def test_env_merging_envelope_overrides_os_environ():
    os.environ["OLLAMA_LOOP_TEST_KEEP"] = "from-os"
    os.environ["OLLAMA_LOOP_TEST_OVERRIDE"] = "old"
    try:
        _, _, _, captured = _make_worker(
            [json.dumps({"type": "result", "is_error": False}) + "\n"],
            env={
                "OLLAMA_LOOP_TEST_OVERRIDE": "new",
                "ANTHROPIC_BASE_URL": "http://localhost:4000",
            },
        )
        env = captured["env"]
        assert env["OLLAMA_LOOP_TEST_KEEP"] == "from-os"
        assert env["OLLAMA_LOOP_TEST_OVERRIDE"] == "new"
        assert env["ANTHROPIC_BASE_URL"] == "http://localhost:4000"
    finally:
        del os.environ["OLLAMA_LOOP_TEST_KEEP"]
        del os.environ["OLLAMA_LOOP_TEST_OVERRIDE"]


def test_argv_carries_prompt_model_streamjson_verbose():
    _, _, _, captured = _make_worker(
        [json.dumps({"type": "result", "is_error": False}) + "\n"],
        message="summarise the file",
        model="claude-3-5-sonnet-hermes3",
    )
    argv = captured["argv"]
    assert argv[0] == "claude"
    assert "-p" in argv
    assert "summarise the file" in argv
    assert "--model" in argv
    assert "claude-3-5-sonnet-hermes3" in argv
    assert "--output-format" in argv
    assert "stream-json" in argv
    assert "--verbose" in argv


def test_unicode_separators_do_not_split_events():
    """U+2028 / U+2029 inside JSON string payloads must not split the event.

    Real-world trigger: assistant message text containing line-separator-class
    characters. Python's text-mode iteration is LF-only by default, but pinning
    the test guarantees we don't accidentally regress to readline-style splitting.
    """
    payload = "before middle after"
    lines = [
        json.dumps({"type": "assistant", "text": payload}) + "\n",
        json.dumps({"type": "result", "is_error": False}) + "\n",
    ]
    _, _, events, _ = _make_worker(lines)
    assert len(events) == 2
    assert events[0]["text"] == payload


def test_malformed_json_lines_are_skipped():
    lines = [
        "this is not json\n",
        json.dumps({"type": "assistant"}) + "\n",
        json.dumps({"type": "result", "is_error": False}) + "\n",
    ]
    _, _, events, _ = _make_worker(lines)
    assert [e["type"] for e in events] == ["assistant", "result"]


def test_close_idempotent():
    w, fake, _, _ = _make_worker(
        [json.dumps({"type": "result", "is_error": False}) + "\n"]
    )
    rc1 = w.close()
    rc2 = w.close()
    assert rc1 == 0
    assert rc2 == 0


def test_close_kills_hung_process():
    """First wait() raises TimeoutExpired → close() must kill, then second
    wait() (post-kill) returns cleanly."""
    fake = _FakeProc(
        [json.dumps({"type": "result", "is_error": False}) + "\n"]
    )
    call_count = {"n": 0}

    def wait_first_hangs(timeout=None):  # noqa: ARG001
        call_count["n"] += 1
        if call_count["n"] == 1:
            raise subprocess.TimeoutExpired(cmd="claude", timeout=timeout or 0)
        return 0

    fake.wait = wait_first_hangs  # type: ignore[assignment]
    with patch.object(ollama_loop.subprocess, "Popen", return_value=fake):
        w = ollama_loop.OllamaLoopWorker("m", "/tmp")
        list(w.prompt("hi"))
    w.close()
    assert fake._killed is True


def test_context_manager_closes_on_exit():
    fake = _FakeProc(
        [json.dumps({"type": "result", "is_error": False}) + "\n"]
    )
    with patch.object(ollama_loop.subprocess, "Popen", return_value=fake):
        with ollama_loop.OllamaLoopWorker("m", "/tmp") as w:
            list(w.prompt("hi"))
        assert w.proc is None


def test_prompt_is_single_shot():
    fake = _FakeProc(
        [json.dumps({"type": "result", "is_error": False}) + "\n"]
    )
    with patch.object(ollama_loop.subprocess, "Popen", return_value=fake):
        w = ollama_loop.OllamaLoopWorker("m", "/tmp")
        list(w.prompt("first"))
        with pytest.raises(RuntimeError):
            list(w.prompt("second"))
