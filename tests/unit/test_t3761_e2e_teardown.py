"""T-3761 — the T-3693 e2e teardown must stop the receivers it started.

Two receivers (t3693a/b) ran 22 h after a live run and sat in the host
receiver registry: `_teardown` ran the receiver stop LAST, after termlink
calls that raise on timeout, so one hung termlink call skipped the stop.

This drives the real `_teardown` against a real receiver in a scratch project
(no claude, no tmux, no hub: `termlink` on PATH is a stub that fails), with
every termlink call made to raise, and asserts nothing survives.
"""

from __future__ import annotations

import importlib.util
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
E2E = FW_ROOT / "tests" / "integration" / "t3693_sidecar_e2e_test.py"


def _load_e2e():
    spec = importlib.util.spec_from_file_location("t3693_e2e_for_t3761", E2E)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = mod      # its dataclasses resolve through sys.modules
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def e2e(tmp_path, monkeypatch):
    stub = tmp_path / "stubbin"
    stub.mkdir()
    (stub / "termlink").write_text("#!/bin/sh\nexit 1\n")
    (stub / "termlink").chmod(0o755)
    monkeypatch.setenv("PATH", f"{stub}:{os.environ['PATH']}")
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "state"))   # isolated registry
    monkeypatch.delenv("FW_SIDECAR_REGISTRY_DIR", raising=False)
    return _load_e2e()


def test_teardown_stops_receiver_when_termlink_steps_raise(e2e, tmp_path, monkeypatch):
    name = f"t3761a-{os.getpid()}"
    agent = e2e.Agent(name, e2e._project(tmp_path, name))
    started = e2e._run([e2e.FW, "sidecar", "receiver", "start"], cwd=agent.root)
    try:
        assert started.returncode == 0, started.stdout + started.stderr
        before = e2e._receiver_survivors(agent)
        assert before.get("pids") and before.get("registry"), before   # the control

        agent.session = "t3761-no-such-session"
        real_run = subprocess.run

        def hung_termlink(argv, *a, **kw):
            if argv and argv[0] == "termlink":
                raise subprocess.TimeoutExpired(argv, kw.get("timeout", 15))
            return real_run(argv, *a, **kw)

        monkeypatch.setattr(subprocess, "run", hung_termlink)
        errors = e2e._teardown(agent)
        monkeypatch.setattr(subprocess, "run", real_run)

        assert any("TimeoutExpired" in err for err in errors), errors
        deadline = time.time() + 10
        left = e2e._receiver_survivors(agent)
        while left and time.time() < deadline:
            time.sleep(0.2)
            left = e2e._receiver_survivors(agent)
        assert left == {}, f"teardown left a receiver behind: {left}"
    finally:
        # Never leak from this test either, pass or fail.
        e2e._run([e2e.FW, "sidecar", "stop", "--quiet"], cwd=agent.root)
        from lib.sidecar import lifecycle
        for pid in lifecycle.live_receiver_pids(name):
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
