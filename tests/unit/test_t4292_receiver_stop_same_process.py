"""T-4292: a receiver started and stopped in the same process reads as dead.

`_start_receiver` Popens the receiver as a child of the caller. After
`cmd_receiver_stop` SIGTERMs it, the child is a zombie until reaped, and
`os.kill(pid, 0)` succeeds on a zombie: stop waited its full deadline, sent
SIGKILL to a corpse, and every later `pid_alive` in that process (tests, the
watcher supervisor) still saw a live receiver.

Every process here is a fixture under tmp_path. The live AEF receiver is never
touched.
"""
import subprocess
import sys
import time
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

import lib.sidecar_cli as cli  # noqa: E402
from lib.sidecar import lifecycle  # noqa: E402


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "t4292"
    (root / ".context" / "sidecar").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t4292\n", encoding="utf-8")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_ENABLED_DIR", str(tmp_path / "enabled"))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "state"))
    monkeypatch.setenv("TERMLINK_RUNTIME_DIR", str(tmp_path / "no-hub"))
    return root


def test_unreaped_child_is_not_alive():
    proc = subprocess.Popen([sys.executable, "-c", "pass"])
    deadline = time.time() + 10
    while time.time() < deadline and not Path(f"/proc/{proc.pid}/stat").read_text().rsplit(")", 1)[1].split()[0] == "Z":
        time.sleep(0.05)
    try:
        assert not lifecycle.pid_alive(proc.pid), "a zombie child read as a live process"
    finally:
        proc.wait()


def test_start_then_stop_in_one_process_leaves_the_receiver_dead(proj, tmp_path):
    agent = f"t4292-{tmp_path.name[-12:]}"
    pid = None
    try:
        rc, _ = cli._start_receiver(agent, None, False, True)
        assert rc == 0
        pid = lifecycle.read_triple_file()["pid"]
        assert lifecycle.pid_alive(pid)
        t0 = time.time()
        cli.cmd_receiver_stop(type("A", (), {"quiet": True, "agent": agent})())
        assert not lifecycle.pid_alive(pid), f"receiver pid {pid} still reads alive after stop"
        assert time.time() - t0 < 4.5, "stop ran to its SIGKILL deadline on an exited receiver"
        assert agent not in [a for _, a in lifecycle.receiver_processes()]
    finally:
        if pid and lifecycle.pid_alive(pid):
            import os
            import signal
            os.kill(pid, signal.SIGKILL)
