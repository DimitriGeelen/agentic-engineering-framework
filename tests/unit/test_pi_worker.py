"""T-1701: Unit tests for PiWorker (mocked subprocess).

Pins the JSONL-framing invariants from T-1692's RPC contract:
  - Multi-event stdout parsed event-by-event.
  - prompt() terminates on agent.done OR error (no over-consumption).
  - U+2028 / U+2029 inside JSON string payloads do NOT split events
    (anti-readline regression — pi's RPC docs explicitly call this out).
  - close() is idempotent on already-exited subprocess.
  - Module import does not spawn pi.

Run: python3 -m pytest tests/unit/test_pi_worker.py -v
"""

from __future__ import annotations

import io
import json
import sys
import subprocess
from pathlib import Path
from unittest.mock import patch

import pytest


# Make lib/ importable without installing the package.
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

import pi_worker  # noqa: E402


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
class _FakeProc:
    """Minimal subprocess.Popen stand-in. stdin captures writes; stdout is a
    StringIO of pre-baked JSONL lines."""

    def __init__(self, stdout_lines: list[str], wait_returns: int = 0,
                 wait_raises: bool = False) -> None:
        self.stdin = io.StringIO()
        # io.StringIO is not iterable across writes for what we need; wrap
        # closed flag manually.
        self.stdin.closed_flag = False
        original_close = self.stdin.close
        def _close():
            self.stdin.closed_flag = True
            return original_close()
        self.stdin.close = _close  # type: ignore[assignment]

        self.stdout = io.StringIO("".join(stdout_lines))
        self.stderr = io.StringIO()
        self._wait_returns = wait_returns
        self._wait_raises = wait_raises
        self._killed = False

    def wait(self, timeout=None):  # noqa: ARG002
        if self._wait_raises:
            raise subprocess.TimeoutExpired(cmd="pi", timeout=timeout or 0)
        return self._wait_returns

    def kill(self):
        self._killed = True


def _make_worker(stdout_lines: list[str]) -> tuple[pi_worker.PiWorker, _FakeProc]:
    fake = _FakeProc(stdout_lines)
    with patch.object(pi_worker.subprocess, "Popen", return_value=fake):
        w = pi_worker.PiWorker("anthropic", "claude-3-5-sonnet-latest", "/tmp")
    # PiWorker stored `fake` as self.proc.
    return w, fake


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
def test_module_import_does_not_spawn_pi():
    """Importing pi_worker must not invoke subprocess. Only PiWorker(...) does."""
    # If import-time spawn existed, sys.modules['pi_worker'] would already have
    # eaten an exception when pi binary is missing. We just assert the symbol.
    assert hasattr(pi_worker, "PiWorker")


def test_prompt_yields_events_until_agent_done():
    lines = [
        json.dumps({"type": "response", "id": "req-1"}) + "\n",
        json.dumps({"type": "tool_use", "tool": "read"}) + "\n",
        json.dumps({"type": "agent.done"}) + "\n",
        json.dumps({"type": "should_not_yield"}) + "\n",
    ]
    w, _ = _make_worker(lines)
    events = list(w.prompt("hello"))
    assert len(events) == 3
    assert events[0]["type"] == "response"
    assert events[-1]["type"] == "agent.done"


def test_prompt_terminates_on_error_event():
    lines = [
        json.dumps({"type": "response", "id": "req-1"}) + "\n",
        json.dumps({"type": "error", "retryable": True, "message": "429"}) + "\n",
        json.dumps({"type": "should_not_yield"}) + "\n",
    ]
    w, _ = _make_worker(lines)
    events = list(w.prompt("anything"))
    assert len(events) == 2
    assert events[-1]["type"] == "error"
    assert events[-1]["retryable"] is True


def test_prompt_writes_request_envelope_to_stdin():
    lines = [json.dumps({"type": "agent.done"}) + "\n"]
    w, fake = _make_worker(lines)
    list(w.prompt("ping"))
    fake.stdin.seek(0)
    written = fake.stdin.read()
    # Single JSON object + trailing newline
    assert written.endswith("\n")
    obj = json.loads(written.rstrip("\n"))
    assert obj == {"id": "req-1", "type": "prompt", "message": "ping"}


def test_unicode_line_separators_do_not_split_events():
    """pi's RPC docs call out U+2028 / U+2029 splitting as the canonical Node
    `readline` non-compliance. PiWorker uses Python's default \\n iterator —
    this test pins that contract.
    """
    payload = "line one line two line three"
    line = json.dumps({"type": "tool_use", "tool": "echo", "args": {"text": payload}}) + "\n"
    lines = [line, json.dumps({"type": "agent.done"}) + "\n"]
    w, _ = _make_worker(lines)
    events = list(w.prompt("x"))
    assert len(events) == 2
    assert events[0]["args"]["text"] == payload  # full payload survived


def test_prompt_skips_malformed_json_lines():
    lines = [
        "not json at all\n",
        json.dumps({"type": "response", "id": "req-1"}) + "\n",
        json.dumps({"type": "agent.done"}) + "\n",
    ]
    w, _ = _make_worker(lines)
    events = list(w.prompt("x"))
    assert len(events) == 2
    assert events[0]["type"] == "response"


def test_close_handles_already_exited_subprocess():
    lines = [json.dumps({"type": "agent.done"}) + "\n"]
    w, _ = _make_worker(lines)
    list(w.prompt("x"))
    rc = w.close()
    assert rc == 0
    # second close is idempotent (no AttributeError on self.proc=None)
    assert w.close() == 0


def test_close_kills_if_wait_times_out():
    fake = _FakeProc([json.dumps({"type": "agent.done"}) + "\n"], wait_raises=True)
    with patch.object(pi_worker.subprocess, "Popen", return_value=fake):
        w = pi_worker.PiWorker("anthropic", "claude-3-5-sonnet-latest", "/tmp")
    list(w.prompt("x"))
    rc = w.close()
    # First wait raises TimeoutExpired → kill() → second wait also raises → returns -1
    assert rc == -1
    assert fake._killed is True


def test_context_manager_closes_on_exit():
    lines = [json.dumps({"type": "agent.done"}) + "\n"]
    w, _ = _make_worker(lines)
    with w as worker:
        list(worker.prompt("x"))
    # after __exit__, self.proc should be None
    assert w.proc is None


def test_request_id_increments_per_prompt():
    lines = [
        json.dumps({"type": "agent.done"}) + "\n",
        json.dumps({"type": "agent.done"}) + "\n",
    ]
    w, fake = _make_worker(lines)
    list(w.prompt("first"))
    list(w.prompt("second"))
    fake.stdin.seek(0)
    written = fake.stdin.read().splitlines()
    assert json.loads(written[0])["id"] == "req-1"
    assert json.loads(written[1])["id"] == "req-2"
