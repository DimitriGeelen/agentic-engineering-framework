"""T-4208 — two sidecar receivers served one inbox; AEF's cron started every project's receiver.

Three legs, one root cause (the AEF tree is treated as the code for every project):

  1. watcher.ensure_all() ran `sidecar_cli.py ensure` from AEF's own tree for
     every enabled project. Each project's OWN launcher must run instead.
  2. Nothing stopped a second receiver for an agent id that already had a live
     one, when that one came from another framework copy (055 kept its vendored
     receiver beside AEF's). The guard reads the process table, so it sees any
     copy's http_server.py, old or new.
  3. ensure must never flip a project's inject setting.

Fake launchers and fake receiver processes; no real receiver is started except
where the guard must refuse before binding.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import lifecycle, watcher  # noqa: E402

SERVER = FW_ROOT / "lib" / "sidecar" / "http_server.py"
CLI = FW_ROOT / "lib" / "sidecar_cli.py"


@pytest.fixture
def host(tmp_path, monkeypatch):
    """Host registry dirs isolated; no project root is the real checkout."""
    monkeypatch.setenv("FW_SIDECAR_ENABLED_DIR", str(tmp_path / "enabled"))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "state"))
    monkeypatch.delenv("PROJECT_ROOT", raising=False)
    monkeypatch.setenv("FRAMEWORK_ROOT", str(FW_ROOT))
    return tmp_path


def _enable(root: Path, agent: str, inject: bool = True) -> None:
    """Enable the project's sidecar the way `fw sidecar start` does: the
    project-local enabled.json and the host-wide record, both written by
    watcher.enable itself."""
    old = os.environ.get("PROJECT_ROOT")
    os.environ["PROJECT_ROOT"] = str(root)
    try:
        watcher.enable(agent, None, inject_on=inject)
    finally:
        if old is None:
            os.environ.pop("PROJECT_ROOT", None)
        else:
            os.environ["PROJECT_ROOT"] = old


def _launcher_script(path: Path, marker: str) -> None:
    """A fake `fw`: records where and with what args it ran, prints one JSON row."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "#!/bin/sh\n"
        f"printf '%s|%s\\n' \"$PWD\" \"$*\" > \"$PWD/{marker}\"\n"
        "echo '{\"action\": \"fake-launcher ran\"}'\n",
        encoding="utf-8")
    path.chmod(0o755)


_ROOTS: list[Path] = []


def _project(base: Path, name: str) -> Path:
    root = base / name
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text(f"project_name: {name}\n", encoding="utf-8")
    _ROOTS.append(root)
    return root


@pytest.fixture(autouse=True)
def _stop_what_the_test_started():
    """Before T-4208's fix, ensure started real receivers and supervisors in
    these temp roots. Stop anything a test left behind, whatever it asserted."""
    yield
    for root in _ROOTS:
        env = dict(os.environ, PROJECT_ROOT=str(root))
        for verb in (["receiver", "stop", "--quiet"], ["stop", "--quiet"]):
            subprocess.run([sys.executable, str(CLI), *verb], cwd=root, env=env,
                           capture_output=True, timeout=60)
    _ROOTS.clear()


# ── leg 1: each project's own launcher ──────────────────────────────────────

def test_ensure_all_runs_the_vendored_launcher_of_a_consumer(host):
    root = _project(host, "consumer")
    _launcher_script(root / ".agentic-framework" / "bin" / "fw", "ran-by.txt")
    _enable(root, "consumer")
    rows = watcher.ensure_all()
    assert len(rows) == 1, rows
    ran = (root / "ran-by.txt").read_text(encoding="utf-8").strip()
    assert ran == f"{root}|sidecar ensure --json", "the project's own vendored launcher must run"
    assert rows[0]["action"] == "fake-launcher ran"


def test_ensure_all_runs_the_own_launcher_of_a_framework_repo(host):
    root = _project(host, "framework-repo")
    (root / "FRAMEWORK.md").write_text("# framework\n", encoding="utf-8")
    _launcher_script(root / "bin" / "fw", "ran-by.txt")
    _enable(root, "framework-repo")
    watcher.ensure_all()
    assert (root / "ran-by.txt").is_file(), "a framework repo runs its own bin/fw"


def test_ensure_all_never_starts_a_project_with_no_launcher(host):
    root = _project(host, "bare")          # no vendored fw, no bin/fw
    _enable(root, "bare")
    rows = watcher.ensure_all()
    assert rows[0]["project_root"] == str(root)
    assert "no framework launcher" in rows[0]["action"], rows
    assert not any(root.glob("**/ran-by.txt")), "no AEF code may start it"
    assert not (root / ".context" / "sidecar" / "receiver.pid").exists(), "no receiver was started"
    assert not (root / ".context" / "sidecar" / "watcher" / "supervisor.pid").exists(), "no supervisor"


def test_ensure_all_drops_the_aef_tree_from_the_child_environment(host, monkeypatch):
    root = _project(host, "envcheck")
    _enable(root, "envcheck")
    # A probe launcher that reports the one variable that would name AEF's tree.
    probe = root / ".agentic-framework" / "bin" / "fw"
    probe.parent.mkdir(parents=True)
    probe.write_text("#!/bin/sh\necho \"FW=${FRAMEWORK_ROOT:-unset}\" > \"$PWD/env.txt\"\n"
                     "echo '{\"action\": \"ok\"}'\n", encoding="utf-8")
    probe.chmod(0o755)
    monkeypatch.setenv("FRAMEWORK_ROOT", "/opt/999-Agentic-Engineering-Framework")
    watcher.ensure_all()
    assert (root / "env.txt").read_text(encoding="utf-8").strip() == "FW=unset"


# ── leg 2: single instance per agent id, across framework copies ────────────

def _foreign_receiver(agent: str, tmp: Path) -> subprocess.Popen:
    """A live process whose argv is a receiver for `agent`, as another copy of
    http_server.py would have it. It sleeps; the guard only reads its argv."""
    copy = tmp / f"other-copy-{agent}-{time.monotonic_ns()}" / "lib" / "sidecar"
    copy.mkdir(parents=True)
    fake = copy / "http_server.py"
    fake.write_text("import time\ntime.sleep(60)\n", encoding="utf-8")
    proc = subprocess.Popen([sys.executable, str(fake), "--port", "0", "--agent", agent])
    deadline = time.time() + 10
    while time.time() < deadline:
        if agent in [a for pid, a in lifecycle.receiver_processes() if pid == proc.pid]:
            break
        time.sleep(0.05)
    return proc


def test_live_receiver_of_another_copy_is_seen_by_the_guard(host):
    proc = _foreign_receiver("t4208-guard-a", host)
    try:
        assert proc.pid in lifecycle.live_receiver_pids("t4208-guard-a")
        assert lifecycle.live_receiver_pids("t4208-no-such-agent") == []
    finally:
        proc.kill()
        proc.wait()


def test_http_server_refuses_to_start_beside_a_live_receiver_for_its_agent(host):
    proc = _foreign_receiver("t4208-guard-b", host)
    root = _project(host, "refuse")
    env = dict(os.environ, PROJECT_ROOT=str(root))
    try:
        # No token is written: the refusal must come before any port is bound.
        res = subprocess.run([sys.executable, str(SERVER), "--port", "0", "--agent", "t4208-guard-b"],
                             cwd=root, env=env, capture_output=True, text=True, timeout=30)
        assert res.returncode == 3, (res.returncode, res.stderr)
        assert "already serve" in res.stderr and str(proc.pid) in res.stderr
        assert not (root / ".context" / "sidecar" / "receiver.pid").exists()
    finally:
        proc.kill()
        proc.wait()


def test_receiver_start_reports_already_running_instead_of_a_second_copy(host):
    proc = _foreign_receiver("t4208-guard-c", host)
    root = _project(host, "start")
    env = dict(os.environ, PROJECT_ROOT=str(root))
    try:
        res = subprocess.run([sys.executable, str(CLI), "receiver", "start", "--agent", "t4208-guard-c",
                              "--quiet", "--no-watcher"],
                             cwd=root, env=env, capture_output=True, text=True, timeout=60)
        assert res.returncode == 1, (res.returncode, res.stdout, res.stderr)
        assert not (root / ".context" / "sidecar" / "receiver.pid").exists()
    finally:
        proc.kill()
        proc.wait()


# ── leg 3: ensure never flips the inject setting ────────────────────────────

def test_ensure_keeps_an_existing_inject_false_config(host, monkeypatch):
    """The project's receiver config is the setting in force; the enabled file
    saying inject:true must not flip it on ensure."""
    root = _project(host, "inject-keep")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    lifecycle.write_config(inject=False)
    _enable(root, "inject-keep", inject=True)
    res = subprocess.run([sys.executable, str(CLI), "ensure", "--json"], cwd=root,
                         env=dict(os.environ, PROJECT_ROOT=str(root)),
                         capture_output=True, text=True, timeout=120)
    assert res.returncode == 0, res.stderr
    cfg = json.loads((root / ".context" / "sidecar" / "receiver" / "config.json").read_text())
    assert cfg == {"inject": False}, f"ensure flipped the inject setting: {cfg}"


# ── doctor fact: two receivers, one agent id ────────────────────────────────

def test_census_reports_two_receivers_for_one_agent(host):
    agent = f"t4208-census-{os.getpid()}"
    a = _foreign_receiver(agent, host)
    b = _foreign_receiver(agent, host)
    try:
        res = subprocess.run([sys.executable, str(CLI), "receiver-census", "--json"],
                             capture_output=True, text=True, timeout=60)
        assert res.returncode == 0, res.stderr
        census = json.loads(res.stdout)
        assert {a.pid, b.pid} <= set(census[agent]), census
    finally:
        for p in (a, b):
            p.kill()
            p.wait()


def test_census_silent_for_one_receiver_per_agent(host):
    agent = f"t4208-single-{os.getpid()}"
    a = _foreign_receiver(agent, host)
    try:
        res = subprocess.run([sys.executable, str(CLI), "receiver-census", "--json"],
                             capture_output=True, text=True, timeout=60)
        census = json.loads(res.stdout)
        assert census[agent] == [a.pid], census
    finally:
        a.kill()
        a.wait()
