"""T-5072 — `fw sidecar receiver start` waited a fixed 10 s for its server.

On node1 (about 3x slower per core, all slots busy) the server needed longer, and 11 of
test_sidecar_receiver_t3693.py's tests failed with "did not come up within 10s"; the 12th
because the timed-out server was still registered. These drive the REAL _start_receiver
with a stand-in server process that answers its health check only after a delay, so the
timing is deterministic instead of depending on how slow the host is.
"""

from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

from lib import sidecar_cli as cli  # noqa: E402


class FakeProc:
    pid = 4242

    def __init__(self):
        self.terminated = False
        self.waited = False
        self.killed = False

    def poll(self):
        return None

    def terminate(self):
        self.terminated = True

    def wait(self, timeout=None):
        self.waited = True
        return 0

    def kill(self):
        self.killed = True


@pytest.fixture
def started(monkeypatch, tmp_path):
    """Patch everything around the wait loop; the server 'answers' after ready_after s."""
    state = {"t0": None, "ready_after": 1.5, "proc": None}

    def fake_popen(*a, **k):
        state["t0"] = time.time()
        state["proc"] = FakeProc()
        return state["proc"]

    def triple():
        if state["t0"] is None:
            return None  # nothing running before the start
        return {"pid": FakeProc.pid, "url": "http://127.0.0.1:1", "port": 1}

    def health(url):
        return state["t0"] is not None and time.time() - state["t0"] >= state["ready_after"]

    monkeypatch.setattr(subprocess, "Popen", fake_popen)
    monkeypatch.setattr(cli.lifecycle, "read_triple_file", triple)
    monkeypatch.setattr(cli.lifecycle, "health", health)
    monkeypatch.setattr(cli.lifecycle, "is_receiver_alive", lambda info: False)
    monkeypatch.setattr(cli.lifecycle, "write_token", lambda *a, **k: None)
    monkeypatch.setattr(cli.lifecycle, "write_config", lambda *a, **k: None)
    monkeypatch.setattr(cli.receiver, "_root", lambda: tmp_path)
    monkeypatch.setattr(cli.receiver, "_receiver_dir", lambda: tmp_path)
    monkeypatch.setattr(cli.identity, "respawn_env", lambda **k: {})
    monkeypatch.setattr(cli, "_reclaim_orphan_receivers", lambda *a, **k: [])
    return state


def test_a_slow_server_fails_with_a_short_limit_and_the_message_names_the_setting(
        started, monkeypatch, capsys):
    monkeypatch.setenv("FW_SIDECAR_RECEIVER_START_S", "1")
    rc, info = cli._start_receiver("t5072", 0, no_inject=True, quiet=True)
    assert rc == 2 and info is None
    err = capsys.readouterr().err
    assert "did not come up within 1s" in err
    assert "FW_SIDECAR_RECEIVER_START_S" in err
    assert "server.log" in err
    # the timed-out server is waited for, so the next start does not find it registered
    assert started["proc"].terminated and started["proc"].waited


def test_the_same_slow_server_starts_when_the_limit_is_raised(started, monkeypatch):
    monkeypatch.setenv("FW_SIDECAR_RECEIVER_START_S", "5")
    t = time.time()
    rc, info = cli._start_receiver("t5072", 0, no_inject=True, quiet=True)
    assert rc == 0 and info["pid"] == FakeProc.pid
    # returns as soon as the server answers, not at the limit
    assert time.time() - t < 3.5


def test_default_limit_is_30s_and_bad_values_fall_back(monkeypatch):
    for raw in ("", "abc", "-1", "0", "inf", "nan"):
        monkeypatch.setenv("FW_SIDECAR_RECEIVER_START_S", raw)
        assert cli._receiver_start_limit() == 30.0, raw
    monkeypatch.setenv("FW_SIDECAR_RECEIVER_START_S", "12.5")
    assert cli._receiver_start_limit() == 12.5
