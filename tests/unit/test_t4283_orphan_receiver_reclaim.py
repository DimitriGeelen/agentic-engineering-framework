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
import os
import signal
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


def test_ensure_reports_a_refused_receiver_start_as_refused(proj, tmp_path, monkeypatch, capsys):
    """Round 2: a receiver start refused by a live receiver of another copy is not
    'running'. Before the fix ensure mapped that rc 1 to a green 'running' while
    the project had no receiver at all (AEF, 16:55-22:45Z 2026-10-17)."""
    import json
    from argparse import Namespace
    from lib.sidecar import watcher

    agent = "t4283-refused"
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    foreign = _orphan(agent, elsewhere, tmp_path)
    watcher.enable(agent, None, inject_on=False)
    monkeypatch.setattr(watcher, "supervisor_alive", lambda: True)
    monkeypatch.setattr(cli, "_ensure_inbox_topic",
                        lambda a, q: {"topic": None, "action": "skipped", "reason": "fixture"})
    try:
        capsys.readouterr()
        assert cli.cmd_ensure(Namespace(all=False, autostart=False, json=True)) == 0
        row = json.loads(capsys.readouterr().out.strip().splitlines()[-1])
        assert row["receiver"] != "running", "a refused start was reported as a running receiver"
        assert row["receiver"].startswith("REFUSED") and str(foreign.pid) in row["receiver"]
    finally:
        watcher.disable()
        foreign.kill()
        foreign.wait()


def test_refused_start_leaves_the_live_stale_receiver_running(proj, tmp_path, monkeypatch):
    """Round 2, the kill: this project's receiver runs stale code, and the start that
    would replace it is going to be refused (a live receiver of another copy serves
    the requested agent). The stale receiver must stay up: before the fix it was
    SIGTERMed and its triple file cleared first, then the start was refused, and
    the project was left with no receiver."""
    from lib.sidecar import watcher

    # Unique per run: a receiver leaked by an earlier run of this test would otherwise
    # still serve the fixed name, and this run's first start would be refused (seen
    # 2026-10-18: passed once, then failed every run until the leak was killed).
    ours, theirs = f"t4283-ours-{tmp_path.name[-12:]}", f"t4283-theirs-{tmp_path.name[-12:]}"
    info, foreign = None, None
    try:
        rc, _ = cli._start_receiver(ours, None, False, True)
        assert rc == 0
        info = lifecycle.read_triple_file()
        elsewhere = tmp_path / "elsewhere"
        elsewhere.mkdir()
        foreign = _orphan(theirs, elsewhere, tmp_path)
        monkeypatch.setattr(watcher, "is_stale", lambda pid: True)
        rc, got = cli._start_receiver(theirs, None, False, True)
        assert rc == 1 and got is None
        assert lifecycle.pid_alive(info["pid"]), "a refused start killed the live receiver"
        assert lifecycle.read_triple_file() == info, "a refused start cleared the triple file"
    finally:
        if foreign is not None:
            foreign.kill()
            foreign.wait()
        monkeypatch.undo()
        cli.cmd_receiver_stop(type("A", (), {"quiet": True, "agent": ours})())
        # cmd_receiver_stop alone left this receiver running: kill it by the pid it recorded.
        if info and info.get("pid") and lifecycle.pid_alive(info["pid"]):
            os.kill(int(info["pid"]), signal.SIGTERM)
