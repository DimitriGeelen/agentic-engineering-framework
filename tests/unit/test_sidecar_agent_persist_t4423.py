"""T-4423: enabled.json must not persist a worker's agent id, and ensure must not replay one.

Origin: this repo's enabled.json held agent 'w4315' (written by the worker of T-4315)
for a day; T-4416 stopped a worker from CALLING ensure, but the next legitimate ensure
(cron, supervisor) read cfg['agent'] and would have restarted the receiver as 'w4315'.

Everything runs in temp projects. Receiver/supervisor spawns are faked, and the live
sidecar of this repo is never touched (T-4315).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

import lib.sidecar_cli as cli  # noqa: E402
from lib.sidecar import identity, watcher  # noqa: E402

PROJ = "proj4423"
WORKER = "w4315"


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / PROJ
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text(f"project_name: {PROJ}\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.chdir(root)   # T-4753: start/stop refuse a PROJECT_ROOT that is not the cwd's project
    monkeypatch.setenv("FW_SIDECAR_ENABLED_DIR", str(tmp_path / "host-enabled"))
    for k in ("FW_DISPATCHED_WORKER", "FW_SIDECAR_AGENT_ID", "FW_REVIEW_WORKER",
              "FW_RAIL_PROJECT_LABEL", "RAIL_PROJECT_LABEL", "TERMLINK_SESSION_ID",
              *identity.IDENTITY_ENV, identity.APPLIED_MARKER):
        monkeypatch.delenv(k, raising=False)
    return root


@pytest.fixture
def fakes(monkeypatch):
    """Receiver / supervisor starts are recorded, not performed. watcher.enable runs
    for real, so what start persists is what enabled.json holds."""
    calls = []

    def recv(agent, *a, **k):
        calls.append(("receiver", agent))
        return 1, {"pid": 1}
    monkeypatch.setattr(cli, "_start_receiver", recv)
    monkeypatch.setattr(cli, "_ensure_inbox_topic",
                        lambda *a, **k: {"topic": None, "ok": True, "action": "skipped", "reason": ""})
    monkeypatch.setattr(watcher, "start_supervisor",
                        lambda *a, **k: calls.append(("supervisor", None)) or {"started": True, "pid": 1})
    monkeypatch.setattr(watcher, "stop_processes", lambda *a, **k: {})
    monkeypatch.setattr(watcher, "supervisor_alive", lambda: False)
    return calls


def _persisted():
    p = watcher.enabled_path()
    return json.loads(p.read_text()).get("agent") if p.exists() else None


def _events(name):
    return [e for e in watcher.read_events() if e.get("event") == name]


# ── (1) start / receiver start refuse to persist a non-project agent ─────────

def test_start_refuses_under_dispatched_worker_even_forced(proj, fakes, monkeypatch, capsys):
    monkeypatch.setenv("FW_DISPATCHED_WORKER", "1")
    for extra in ([], ["--force"], ["--i-am-human"]):
        assert cli.main(["start", "--quiet", "--agent", PROJ, *extra]) == 2
    assert _persisted() is None and not fakes
    assert "FW_DISPATCHED_WORKER" in capsys.readouterr().err


def test_start_refuses_foreign_agent(proj, fakes, capsys):
    assert cli.main(["start", "--quiet", "--agent", WORKER]) == 2
    assert _persisted() is None and not fakes
    err = capsys.readouterr().err
    assert WORKER in err and PROJ in err and "--force" in err


def test_start_refuses_foreign_agent_from_session_env(proj, fakes, monkeypatch):
    """The real route: no --agent, the session's FW_SIDECAR_AGENT_ID names the worker."""
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", WORKER)
    assert cli.main(["start", "--quiet"]) == 2
    assert _persisted() is None


def test_start_foreign_agent_with_force_persists(proj, fakes):
    assert cli.main(["start", "--quiet", "--agent", WORKER, "--force"]) == 0
    assert _persisted() == WORKER


def test_start_project_agent_persists(proj, fakes):
    """Control: the project's own agent starts without any flag."""
    assert cli.main(["start", "--quiet", "--agent", PROJ]) == 0
    assert _persisted() == PROJ


def test_receiver_start_with_watcher_refuses_foreign_agent(proj, fakes):
    assert cli.main(["receiver", "start", "--quiet", "--agent", WORKER]) == 2
    assert _persisted() is None and not fakes


def test_receiver_start_no_watcher_persists_nothing_and_is_not_refused(proj, fakes):
    """--no-watcher writes no enabled.json, so there is nothing to protect."""
    assert cli.main(["receiver", "start", "--quiet", "--no-watcher", "--agent", WORKER]) == 1
    assert _persisted() is None and fakes == [("receiver", WORKER)]


# ── (2) ensure / supervisor never replay a persisted foreign agent ───────────

def test_ensure_uses_project_agent_on_mismatch(proj, fakes, capsys):
    watcher.enable(WORKER, None, True)
    assert cli.main(["ensure", "--json"]) == 0
    assert ("receiver", PROJ) in fakes and ("receiver", WORKER) not in fakes
    ev = _events("ENSURE_AGENT_MISMATCH")
    assert ev and ev[-1]["persisted"] == WORKER and ev[-1]["project"] == PROJ
    assert _persisted() == WORKER          # nothing rewritten silently
    assert "ENSURE_AGENT_MISMATCH" in capsys.readouterr().err


def test_ensure_matching_agent_records_no_mismatch(proj, fakes):
    watcher.enable(PROJ, None, True)
    assert cli.main(["ensure", "--json"]) == 0
    assert ("receiver", PROJ) in fakes and not _events("ENSURE_AGENT_MISMATCH")


def test_supervisor_restart_receiver_uses_project_agent(proj, monkeypatch):
    seen = {}

    def fake_run(argv, **kw):
        seen["argv"] = argv
        return subprocess.CompletedProcess(argv, 0, "", "")
    monkeypatch.setattr(watcher.subprocess, "run", fake_run)
    watcher._restart_receiver({"agent": WORKER})
    argv = seen["argv"]
    assert argv[argv.index("--agent") + 1] == PROJ
    assert _events("ENSURE_AGENT_MISMATCH")


# ── (3) liveness / doctor / audit WARN on the persisted mismatch ─────────────

def _fresh_liveness(name):
    now = datetime.now(timezone.utc).isoformat()
    watcher.write_liveness({"identity": name, "seq": 7, "last_probe_at": now,
                            "last_probe_ok": True, "updated_at": now, "tick_s": 30})


def test_liveness_warns_on_persisted_mismatch_but_stays_live(proj):
    watcher.enable(WORKER, None, True)
    _fresh_liveness(PROJ)                  # ensure brought it up as the project agent
    v = watcher.liveness_verdict()
    assert v["state"] == "live"
    msg = " ".join(v["warnings"])
    assert WORKER in msg and PROJ in msg and "fw sidecar start" in msg


def test_liveness_no_warning_when_agent_matches(proj):
    watcher.enable(PROJ, None, True)
    _fresh_liveness(PROJ)
    v = watcher.liveness_verdict()
    assert v["state"] == "live" and v["warnings"] == []


def test_watcher_facts_carry_the_warning(proj):
    """lib/sidecar-audit.sh is the one fact source fw doctor and fw audit read."""
    watcher.enable(WORKER, None, True)
    _fresh_liveness(PROJ)
    out = subprocess.run(
        ["bash", "-c", f'source "{FW_ROOT}/lib/sidecar-audit.sh" && fw_sidecar_watcher_facts "$1"',
         "_", str(proj)],
        env=dict(os.environ, PROJECT_ROOT=str(proj)), capture_output=True, text=True, timeout=120)
    assert out.returncode == 0, out.stderr
    fields = out.stdout.rstrip("\n").split("\t")
    assert len(fields) == 8 and fields[0] == "live"
    assert WORKER in fields[7] and PROJ in fields[7]


def test_doctor_and_audit_read_the_warnings_field():
    """Both consumers read the 8th field and WARN on it (static: running fw doctor
    or fw audit here would read this repo's live sidecar)."""
    for path in ("bin/fw", "agents/audit/audit.sh"):
        text = (FW_ROOT / path).read_text()
        assert "_sw_wake _sw_warn" in text, path
        assert "T-4423" in text, path
