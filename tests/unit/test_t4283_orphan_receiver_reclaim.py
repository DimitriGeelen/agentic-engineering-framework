"""T-4283: a live receiver with no triple file blocks every restart.

The T-4208 rival guard refuses a second receiver for an agent while any live
http_server.py serves that agent. A receiver whose pid/port/url were cleared is
still alive but unreachable (the probe reads "receiver not running"), so the
guard refuses every restart: the watcher's restart returns rc=1 forever and
`fw sidecar ensure` reports the receiver as "running". An orphan that runs in
THIS project's root is ours and must be reclaimed; one from another copy is not.

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
    root = tmp_path / "t4283"
    (root / ".context" / "sidecar").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t4283\n", encoding="utf-8")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_ENABLED_DIR", str(tmp_path / "enabled"))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "state"))
    monkeypatch.setenv("TERMLINK_RUNTIME_DIR", str(tmp_path / "no-hub"))
    return root


def _orphan(agent: str, cwd: Path, tmp: Path) -> subprocess.Popen:
    """A live process whose argv is a receiver for `agent`, running in `cwd`.
    It sleeps; the guard only reads its argv and its working directory."""
    copy = tmp / f"copy-{agent}-{time.monotonic_ns()}"
    copy.mkdir(parents=True)
    fake = copy / "http_server.py"
    fake.write_text("import time\ntime.sleep(60)\n", encoding="utf-8")
    proc = subprocess.Popen([sys.executable, str(fake), "--port", "0", "--agent", agent],
                            cwd=str(cwd))
    deadline = time.time() + 10
    while time.time() < deadline:
        if agent in [a for pid, a in lifecycle.receiver_processes() if pid == proc.pid]:
            break
        time.sleep(0.05)
    return proc


def test_orphan_receiver_of_this_project_is_reclaimed_so_start_proceeds(proj, tmp_path, monkeypatch):
    agent = "t4283-orphan"
    monkeypatch.setattr(cli, "ORPHAN_MIN_AGE_S", 0.0)   # the fixture orphan is seconds old
    orphan = _orphan(agent, proj, tmp_path)
    assert lifecycle.read_triple_file() is None
    try:
        rc, _ = cli._start_receiver(agent, None, False, True)
        assert rc == 0, "the orphan blocked the start (rc=1): the project stays dead"
        assert orphan.wait(timeout=10) is not None, "the orphan of this project was not stopped"
        info = lifecycle.read_triple_file()
        assert info and lifecycle.is_receiver_alive(info)
    finally:
        if orphan.poll() is None:
            orphan.kill()
            orphan.wait()
        cli.cmd_receiver_stop(type("A", (), {"quiet": True, "agent": agent})())


def test_orphan_of_another_copy_is_left_alone(proj, tmp_path):
    agent = "t4283-foreign"
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    foreign = _orphan(agent, elsewhere, tmp_path)
    try:
        rc, _ = cli._start_receiver(agent, None, False, True)
        assert rc == 1, "a receiver from another copy must still block a second one (T-4208)"
        assert foreign.poll() is None, "a receiver of another project was stopped"
    finally:
        foreign.kill()
        foreign.wait()


def test_receiver_still_booting_in_this_project_is_not_reclaimed(proj, tmp_path):
    """The race the age guard exists for: a concurrent start must not stop a
    receiver that is still binding (no triple file yet, but seconds old)."""
    agent = "t4283-booting"
    booting = _orphan(agent, proj, tmp_path)
    try:
        rc, _ = cli._start_receiver(agent, None, False, True)
        assert rc == 1, "a booting receiver of this project was treated as an orphan"
        assert booting.poll() is None, "a booting receiver was stopped by a concurrent start"
    finally:
        booting.kill()
        booting.wait()


def test_ensure_restarts_a_receiver_the_watcher_reports_as_not_running(proj, tmp_path, monkeypatch):
    """The cron / SessionStart entry: an enabled project whose receiver is gone (the
    watcher's probe says 'receiver not running') gets its receiver back."""
    from argparse import Namespace
    from lib.sidecar import watcher

    agent = "t4283-ensure"
    monkeypatch.setattr(cli, "ORPHAN_MIN_AGE_S", 0.0)
    orphan = _orphan(agent, proj, tmp_path)
    watcher.enable(agent, None, inject_on=False)
    try:
        assert cli.cmd_ensure(Namespace(all=False, autostart=False, json=False)) == 0
        assert orphan.wait(timeout=10) is not None, "ensure left the blocking receiver running"
        info = lifecycle.read_triple_file()
        assert info and lifecycle.is_receiver_alive(info), "ensure did not restart the receiver"
    finally:
        watcher.stop_all()
        if orphan.poll() is None:
            orphan.kill()
            orphan.wait()
        cli.cmd_receiver_stop(Namespace(quiet=True, agent=agent))
