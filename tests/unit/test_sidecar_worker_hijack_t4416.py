"""T-4416: a dispatched worker must not restart the PROJECT sidecar under its own identity.

Origin: ring20 T-2430 (msg 82c0e984, v1.8.12). A worker dispatched by `fw termlink
dispatch` (FW_DISPATCHED_WORKER=1, FW_SIDECAR_AGENT_ID=<worker>, its own TMUX_PANE and
TERMLINK_SESSION_ID) ran the SessionStart autostart; `sidecar ensure` saw stale code and
respawned supervisor, watcher and receiver with the worker's env, so delivery pointed at
the worker's pane after it exited.

Everything runs in temp projects. Spawns are captured by fakes (no real supervisor,
watcher or receiver starts), and the live sidecar of this repo is never touched (T-4315).
"""
from __future__ import annotations

import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

import lib.sidecar_cli as cli  # noqa: E402
from lib.sidecar import identity, watcher  # noqa: E402

WORKER_ENV = {
    "FW_DISPATCHED_WORKER": "1",
    "FW_SIDECAR_AGENT_ID": "triage-backlog",
    "TMUX_PANE": "%99",
    "TMUX": "/tmp/tmux-0/default,1,0",
    "TERMLINK_SESSION_ID": "worker-session",
    "CLAUDECODE": "1",
    "CLAUDE_CODE_ENTRYPOINT": "sdk-cli",
    "FW_FOCUS_SESSION_KEY": "triage-backlog",
}


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "proj4416"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: proj4416\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_ENABLED_DIR", str(tmp_path / "host-enabled"))
    for k in (*WORKER_ENV, "FW_REVIEW_WORKER", "FW_RAIL_PROJECT_LABEL",
              *identity.IDENTITY_ENV, identity.APPLIED_MARKER):
        monkeypatch.delenv(k, raising=False)
    return root


@pytest.fixture
def no_spawn(monkeypatch):
    """Every start the ensure path could make is recorded instead of performed."""
    calls = []

    def _rec(name, ret):
        def f(*a, **k):
            calls.append(name)
            return ret
        return f
    monkeypatch.setattr(cli, "_start_receiver", _rec("receiver", (1, {"pid": 1})))
    monkeypatch.setattr(cli, "_start_watcher", _rec("watcher", {"reason": "faked"}))
    monkeypatch.setattr(cli, "_ensure_inbox_topic",
                        _rec("topic", {"topic": None, "ok": True, "action": "skipped", "reason": ""}))
    monkeypatch.setattr(watcher, "start_supervisor", _rec("supervisor", {"started": True, "pid": 1}))
    monkeypatch.setattr(watcher, "stop_processes", _rec("stop", {}))
    monkeypatch.setattr(watcher, "ensure_all", _rec("ensure_all", []))
    return calls


# ── (1) ensure refuses to act for a dispatched worker ─────────────────────────

def test_ensure_autostart_skips_for_dispatched_worker(proj, no_spawn, monkeypatch, capsys):
    monkeypatch.setenv("FW_DISPATCHED_WORKER", "1")
    assert cli.main(["ensure", "--autostart"]) == 0
    assert not {"receiver", "watcher", "supervisor"} & set(no_spawn)
    assert "skipped" in capsys.readouterr().out
    assert any(e.get("event") == "ENSURE_SKIPPED_WORKER" for e in watcher.read_events())


def test_ensure_skips_when_agent_id_is_not_the_project(proj, no_spawn, monkeypatch, capsys):
    watcher.enable("proj4416", None, True)   # an enabled project sidecar, stale-restart path
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "triage-backlog")
    assert cli.main(["ensure"]) == 0
    assert not {"receiver", "watcher", "supervisor", "stop"} & set(no_spawn)
    assert "triage-backlog" in capsys.readouterr().out


def test_ensure_runs_for_the_project_agent(proj, no_spawn, monkeypatch):
    """Control: the project's own session (agent id unset or == project) still ensures."""
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "proj4416")
    assert cli.main(["ensure", "--autostart"]) == 0
    assert "receiver" in no_spawn


def test_ensure_all_still_runs_from_a_worker(proj, no_spawn, monkeypatch):
    monkeypatch.setenv("FW_DISPATCHED_WORKER", "1")
    assert cli.main(["ensure", "--all"]) == 0
    assert no_spawn == ["ensure_all"]


# ── (2) every respawn runs with a scrubbed env ───────────────────────────────

def _assert_scrubbed(env: dict):
    for k in ("FW_DISPATCHED_WORKER", "FW_SIDECAR_AGENT_ID", "TMUX_PANE", "TMUX",
              "TERMLINK_SESSION_ID", "CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT", "FW_FOCUS_SESSION_KEY"):
        assert k not in env, k
    assert env.get("PATH")


def test_respawn_env_drops_worker_identity_and_applies_rail_identity(proj, monkeypatch):
    for k, v in WORKER_ENV.items():
        monkeypatch.setenv(k, v)
    monkeypatch.setenv("FW_SIDECAR_RAIL_IDENTITY", "1")
    monkeypatch.setenv("FW_RAIL_IDENTITY_FILE", "keys/own.key")
    env = identity.respawn_env(root=str(proj))
    _assert_scrubbed(env)
    assert env["PROJECT_ROOT"] == str(proj)
    assert env["TERMLINK_IDENTITY_FILE"] == str(proj / "keys/own.key")


class _Proc:
    pid = 4242
    returncode = 1

    def poll(self):
        return 1


def test_supervisor_spawn_is_scrubbed(proj, monkeypatch):
    for k, v in WORKER_ENV.items():
        monkeypatch.setenv(k, v)
    seen = {}

    def fake_popen(argv, **kw):
        seen["env"] = kw["env"]
        return _Proc()
    monkeypatch.setattr(watcher.subprocess, "Popen", fake_popen)
    watcher._spawn(["supervise"], "supervisor.log")
    _assert_scrubbed(seen["env"])


def test_restart_receiver_is_scrubbed(proj, monkeypatch):
    for k, v in WORKER_ENV.items():
        monkeypatch.setenv(k, v)
    seen = {}

    def fake_run(argv, **kw):
        seen["env"] = kw["env"]
        return subprocess.CompletedProcess(argv, 0, "", "")
    monkeypatch.setattr(watcher.subprocess, "run", fake_run)
    watcher._restart_receiver({"agent": "proj4416"})
    _assert_scrubbed(seen["env"])


def test_cli_receiver_start_is_scrubbed(proj, monkeypatch):
    for k, v in WORKER_ENV.items():
        monkeypatch.setenv(k, v)
    seen = {}

    def fake_popen(argv, **kw):
        seen["env"] = kw["env"]
        return _Proc()
    monkeypatch.setattr(subprocess, "Popen", fake_popen)
    rc, _ = cli._start_receiver("proj4416", None, True, True)
    assert rc == 2        # the fake exits before binding; only the env matters here
    _assert_scrubbed(seen["env"])


def test_ensure_all_children_are_scrubbed(proj, tmp_path, monkeypatch):
    (proj / "bin").mkdir()
    (proj / "bin" / "fw").write_text("#!/bin/sh\n")
    (proj / "FRAMEWORK.md").write_text("")
    watcher.enable("proj4416", None, True)
    for k, v in WORKER_ENV.items():
        monkeypatch.setenv(k, v)
    seen = {}

    def fake_run(argv, **kw):
        seen["env"] = kw["env"]
        return subprocess.CompletedProcess(argv, 0, '{"action": "ok"}\n', "")
    monkeypatch.setattr(watcher.subprocess, "run", fake_run)
    rows = watcher.ensure_all()
    assert rows and rows[0]["action"] == "ok"
    _assert_scrubbed(seen["env"])
    assert "FRAMEWORK_ROOT" not in seen["env"]


# ── (3) liveness: a sidecar running under another agent's identity is not live ─

def _fresh_liveness(identity_name: str):
    now = datetime.now(timezone.utc).isoformat()
    watcher.write_liveness({"identity": identity_name, "seq": 7, "last_probe_at": now,
                            "last_probe_ok": True, "updated_at": now, "tick_s": 30})


def test_liveness_flags_foreign_identity(proj):
    watcher.enable("triage-backlog", None, True)
    _fresh_liveness("triage-backlog")
    v = watcher.liveness_verdict()
    assert v["state"] == "not-live"
    msg = " ".join(v["reasons"])
    assert "triage-backlog" in msg and "proj4416" in msg and "fw sidecar start" in msg


def test_liveness_live_for_project_identity(proj):
    """Control: same fresh tick under the project's own agent is live."""
    watcher.enable("proj4416", None, True)
    _fresh_liveness("proj4416")
    assert watcher.liveness_verdict()["state"] == "live"


# ── (1) the SessionStart hook itself ─────────────────────────────────────────

def _run_autostart(proj, tmp_path, extra):
    fake_fw = tmp_path / "fakefw"
    (fake_fw / "lib").mkdir(parents=True)
    marker = tmp_path / "ensure-ran"
    (fake_fw / "lib" / "sidecar_cli.py").write_text(
        f"open({str(marker)!r}, 'w').write('ran')\n")
    env = {k: v for k, v in os.environ.items() if k not in WORKER_ENV}
    env.update(PROJECT_ROOT=str(proj), FRAMEWORK_ROOT=str(fake_fw), **extra)
    subprocess.run(["bash", str(FW_ROOT / "agents/context/sidecar-autostart.sh")],
                   input="", env=env, timeout=30, check=True)
    return marker


def test_autostart_hook_skips_dispatched_worker(proj, tmp_path):
    marker = _run_autostart(proj, tmp_path, {"FW_DISPATCHED_WORKER": "1"})
    time.sleep(1.0)
    assert not marker.exists()
    log = (proj / ".context/sidecar/watcher/autostart.log").read_text()
    assert "FW_DISPATCHED_WORKER" in log


def test_autostart_hook_runs_for_a_plain_session(proj, tmp_path):
    marker = _run_autostart(proj, tmp_path, {})
    deadline = time.time() + 10
    while time.time() < deadline and not marker.exists():
        time.sleep(0.1)
    assert marker.exists()
