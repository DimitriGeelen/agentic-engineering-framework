"""T-3777 — a sidecar whose PROJECT_ROOT is deleted under it must end, and must
not recreate the tree it was serving.

Origin: unit tests ran claude-fw against tmp fixtures, each started a real
always-on sidecar, and the fixture's teardown failed 'Directory not empty'
because the supervisor kept writing (and respawning the receiver) into the
deleted tmpdir. Real processes, started through the CLI, as in
test_sidecar_watcher_t3684.py.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import lifecycle, watcher  # noqa: E402

CLI = [sys.executable, str(FW_ROOT / "lib" / "sidecar_cli.py")]
NO_TERMLINK_PATH = "/usr/bin:/bin"


@pytest.fixture
def proj(tmp_path, monkeypatch):
    agent = f"t3777-{os.getpid()}"
    root = tmp_path / agent
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t3777\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", agent)
    monkeypatch.setenv("FW_SIDECAR_ORPHAN_CHECK_S", "1")
    for k in ("FW_SIDECAR_TICK", "FW_REVIEW_WORKER", "FW_DISPATCHED_WORKER", "TERMLINK_SESSION_ID"):
        monkeypatch.delenv(k, raising=False)
    pids: list[int] = []
    yield root, agent, pids
    for pid in pids:   # never leak a sidecar, whatever the assertions said
        if lifecycle.pid_alive(pid):
            os.kill(pid, 9)


def _cli(root, *args):
    env = dict(os.environ, PROJECT_ROOT=str(root), PATH=NO_TERMLINK_PATH)
    return subprocess.run(CLI + list(args), cwd=root, env=env, capture_output=True,
                          text=True, timeout=90)


def _wait(pred, timeout=30.0, step=0.2):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if pred():
            return True
        time.sleep(step)
    return bool(pred())


def test_sidecar_ends_and_does_not_recreate_a_deleted_project_root(proj):
    root, agent, pids = proj
    out = _cli(root, "start", "--tick", "1", "--agent", agent)
    assert out.returncode == 0, out.stdout + out.stderr
    assert _wait(lambda: watcher.supervisor_alive() and watcher.read_pid("watcher")
                 and lifecycle.read_triple_file())
    pids += [watcher.read_pid("supervisor"), watcher.read_pid("watcher"),
             lifecycle.read_triple_file()["pid"]]

    shutil.rmtree(root)

    assert _wait(lambda: not any(lifecycle.pid_alive(p) for p in pids)), \
        f"sidecar processes still alive after their project was deleted: " \
        f"{[p for p in pids if lifecycle.pid_alive(p)]}"
    time.sleep(1.5)   # a respawned receiver would have written by now
    assert not root.exists(), sorted(str(p) for p in root.rglob("*"))


def test_supervisor_exits_without_mkdir_when_root_is_gone(tmp_path, monkeypatch):
    """Unit leg: supervise() against a root that does not exist returns at once
    and writes nothing (read_enabled() used to mkdir the tree back)."""
    root = tmp_path / "gone"
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    restarted = []
    monkeypatch.setattr(watcher, "_restart_receiver", lambda cfg: restarted.append(cfg))
    assert watcher.supervise() == 0
    assert not root.exists() and restarted == []


def test_claude_fw_sidecar_opt_out_starts_nothing(tmp_path):
    """CLAUDE_FW_NO_SIDECAR=1 (T-3747): the wrapper's sidecar_start is a no-op."""
    root = tmp_path / "optout"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: optout\n")
    stub = tmp_path / "stubbin"
    stub.mkdir()
    (stub / "claude").write_text("#!/bin/sh\necho stub-claude\nexit 0\n")
    (stub / "claude").chmod(0o755)
    env = {"HOME": os.environ["HOME"], "PATH": f"{stub}:{NO_TERMLINK_PATH}",
           "FW_SIDECAR_ENABLED_DIR": os.environ["FW_SIDECAR_ENABLED_DIR"],
           "FW_SIDECAR_REGISTRY_DIR": os.environ["FW_SIDECAR_REGISTRY_DIR"],
           "CLAUDE_FW_NO_SIDECAR": "1"}
    out = subprocess.run([str(FW_ROOT / "bin" / "claude-fw"), "--no-restart"], cwd=root,
                         env=env, capture_output=True, text=True, timeout=180)
    text = out.stdout + out.stderr
    assert "stub-claude" in text, text[-2000:]
    assert "sidecar watcher running" not in text
    assert not (root / ".context" / "sidecar" / "watcher" / "supervisor.pid").exists()
    assert not list(Path(os.environ["FW_SIDECAR_ENABLED_DIR"]).glob("*.json"))
