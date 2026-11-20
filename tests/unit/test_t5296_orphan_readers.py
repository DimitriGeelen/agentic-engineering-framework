"""T-5296: an inbox another project's reader holds is not an orphan.

Origin: 010-termlink msg 13d7f876 (2026-11-20). `fw sidecar orphan-inboxes` named
inbox:<hub>/termlink, claude-termlink and claude-termlink-alt although 010's AEF
sidecar and proven Rust test sidecars read them. The check now asks the hub
(`termlink hub inbox consumers <topic> --json`): a named or proven reader clears
the candidate; an unnamed `claimed` read alone does not (it may be a diagnostic
read); a failed call keeps the candidate and marks the check partial.

Every hub answer comes from a fake `termlink` on PATH; nothing reaches a real hub.
"""
from __future__ import annotations

import importlib
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

OWN = "cacc73ea32b121dd"
PROJECT = "999-Agentic-Engineering-Framework"
TOPIC = f"inbox:{OWN}/stray-nick"
ROWS = {"topics": [{"name": TOPIC, "count": 4, "latest_offset": 3,
                    "activity": {"unread_since_ms": None, "last_writer": "abc"}}]}


def _consumer(agent, strength):
    return {"actions": ["read"], "agent": agent, "first_ms": 1, "last_ms": 2,
            "strength": strength, "instance": "local"}


def _fake_termlink(tmp_path, consumers=None, consumers_rc=0):
    d = tmp_path / "fakebin"
    d.mkdir(exist_ok=True)
    (d / "rows.json").write_text(json.dumps(ROWS))
    (d / "cons.json").write_text(json.dumps(
        {"bound": None, "consumers": consumers or [], "topic": TOPIC, "window_s": 86400}))
    (d / "calls.log").write_text("")
    (d / "termlink").write_text(
        "#!/bin/sh\n"
        f'echo "$*" >> "{d}/calls.log"\n'
        f'if [ "$1 $2" = "channel list" ]; then cat "{d}/rows.json"; exit 0; fi\n'
        f'if [ "$1 $2 $3" = "hub inbox consumers" ]; then '
        f'[ {consumers_rc} -eq 0 ] || {{ echo "hub unreachable" >&2; exit {consumers_rc}; }}; '
        f'cat "{d}/cons.json"; exit 0; fi\n'
        "exit 9\n")
    (d / "termlink").chmod(0o755)
    return d


@pytest.fixture()
def env(tmp_path, monkeypatch):
    proj = tmp_path / PROJECT
    (proj / ".context" / "sidecar").mkdir(parents=True)
    (proj / ".framework.yaml").write_text("project: x\n")
    monkeypatch.setenv("PROJECT_ROOT", str(proj))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", OWN)
    for k in ("FW_SIDECAR_AGENT_ID", "TERMLINK_SESSION", "FW_FOCUS_SESSION_KEY",
              "RAIL_PROJECT_LABEL", "FW_RAIL_PROJECT_LABEL"):
        monkeypatch.delenv(k, raising=False)

    def setup(**kw):
        d = _fake_termlink(tmp_path, **kw)
        monkeypatch.setenv("PATH", f"{d}{os.pathsep}{os.environ['PATH']}")
        import lib.sidecar.circuit as circuit
        import lib.sidecar.inbox as inbox
        import lib.sidecar.addressing as addressing
        for m in (circuit, inbox, addressing):
            importlib.reload(m)
        return addressing, d
    return setup


def test_proven_reader_is_not_an_orphan(env):
    addressing, d = env(consumers=[_consumer("(unnamed)", "proven")])
    assert addressing.orphan_inboxes() == []
    calls = (d / "calls.log").read_text().splitlines()
    assert sum(c.startswith("hub inbox consumers") for c in calls) == 1
    assert f"hub inbox consumers {TOPIC} --json" in calls


def test_named_claimed_reader_is_not_an_orphan(env):
    addressing, _ = env(consumers=[_consumer("010-termlink", "claimed")])
    assert addressing.orphan_inboxes() == []


def test_only_unnamed_claimed_reader_stays_an_orphan(env):
    addressing, _ = env(consumers=[_consumer("(unnamed)", "claimed")])
    got = addressing.orphan_inboxes()
    assert [r["topic"] for r in got] == [TOPIC]
    assert "readers_checked" not in got[0]


def test_failed_consumers_call_stays_an_orphan_marked_partial(env, tmp_path):
    addressing, d = env(consumers_rc=3)
    got = addressing.orphan_inboxes()
    assert [r["topic"] for r in got] == [TOPIC]
    assert got[0]["readers_checked"] is False
    assert "rc=3" in got[0]["readers_reason"]
    e = dict(os.environ, PATH=f"{d}{os.pathsep}{os.environ['PATH']}")
    p = subprocess.run([sys.executable, str(FW_ROOT / "lib" / "sidecar_cli.py"), "orphan-inboxes"],
                       env=e, capture_output=True, text=True, timeout=60)
    assert p.returncode == 1, p.stderr
    assert TOPIC in p.stdout and "partial check" in p.stdout, p.stdout
