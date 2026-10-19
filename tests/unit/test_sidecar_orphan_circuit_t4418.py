"""T-4418: a send to an explicit circuit nobody reads must not succeed silently.

Origin: ring20 msg 1fa56c18 (their T-2431). 2026-10-05..19, 14 consults went to
`inbox:22c19fedafd73da2/ring20-manager` — `ring20-manager` is a hub profile nickname,
the project is `proxmox-ring20-management`. `send --to 22c19fedafd73da2/ring20-manager
--hub ring20-manager` was used verbatim (explicit circuit), `--ensure-topic` created the
topic, and the hub's acceptance was reported as delivered — although the sender's
peers.json held the right circuit.

Every hub answer here comes from a fake runner or a fake `termlink` on PATH; nothing
reaches a real hub, and no sidecar process is started (T-4315).
"""
from __future__ import annotations

import importlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

OWN = "cacc73ea32b121dd"
THEIRS = "22c19fedafd73da2"
PROJECT = "999-Agentic-Engineering-Framework"
NOW = int(time.time() * 1000)
DAY = 86_400_000


def _row(name, count=5, write=NOW - DAY, fetch=None, unread=None):
    return {"name": name, "count": count,
            "activity": {"last_write_ms": write, "last_data_fetch_ms": fetch,
                         "last_fetch_ms": fetch, "unread_since_ms": unread}}


# The ring20 hub as measured: the nickname topic was written and never fetched; the
# real project's inbox is read.
RING20 = [
    _row(f"inbox:{THEIRS}/ring20-manager", count=14, write=NOW - DAY, unread=NOW - 14 * DAY),
    _row(f"inbox:{THEIRS}/proxmox-ring20-management", count=14, write=NOW - DAY, fetch=NOW - 60_000),
    _row(f"inbox:{THEIRS}/proxmox-ring20-management/w77", count=2, write=NOW - DAY, unread=NOW - DAY),
]


class _Proc:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode, self.stdout, self.stderr = returncode, stdout, stderr


def _runner(rows, calls=None, rc=0):
    def run(argv, **kw):
        if calls is not None:
            calls.append(argv[1:])
        if argv[1:3] == ["channel", "list"]:
            prefix = argv[argv.index("--prefix") + 1]
            return _Proc(rc, json.dumps({"topics": [r for r in rows if r["name"].startswith(prefix)]}))
        raise AssertionError(argv)
    return run


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
    import lib.sidecar.addressing as addressing
    importlib.reload(addressing)
    return addressing


def _learn(addressing, name, cid):
    data = addressing.load_peers()
    data["peers"][name] = {"circuit": cid, "hub_id": cid.split("/")[0], "learned_at": "t"}
    addressing._save_peers(data)


# ── evidence, unit level ─────────────────────────────────────────────────────

def test_nickname_circuit_on_a_remote_hub_has_no_evidence(env):
    ev = env.explicit_circuit_evidence(f"{THEIRS}/ring20-manager", "ring20-manager",
                                       runner=_runner(RING20), now_ms=NOW)
    assert ev["known"] is None
    assert f"{THEIRS}/proxmox-ring20-management" in ev["candidates"]
    assert all("ring20-manager" != c.split("/")[-1] for c in ev["candidates"])
    assert not any(c.endswith("/w77") for c in ev["candidates"])   # project level only


def test_read_topic_is_evidence(env):
    ev = env.explicit_circuit_evidence(f"{THEIRS}/proxmox-ring20-management", "ring20-manager",
                                       runner=_runner(RING20), now_ms=NOW)
    assert ev["known"] and "read" in ev["known"]


def test_fetch_older_than_last_write_or_window_is_not_evidence(env):
    rows = [_row(f"inbox:{THEIRS}/x", write=NOW - DAY, fetch=NOW - 2 * DAY),
            _row(f"inbox:{THEIRS}/y", write=NOW - 30 * DAY, fetch=NOW - 20 * DAY)]
    for name in ("x", "y"):
        assert env.explicit_circuit_evidence(f"{THEIRS}/{name}", "h", runner=_runner(rows),
                                             now_ms=NOW)["known"] is None


def test_peer_directory_circuit_is_evidence_without_a_hub_call(env):
    _learn(env, "proxmox-ring20-management", f"{THEIRS}/proxmox-ring20-management")
    calls = []
    ev = env.explicit_circuit_evidence(f"{THEIRS}/proxmox-ring20-management", "h",
                                       runner=_runner([], calls), now_ms=NOW)
    assert ev["known"] == "peer directory" and calls == []


def test_peer_directory_entries_on_that_hub_are_named_as_known_circuits(env):
    _learn(env, "proxmox-ring20-management", f"{THEIRS}/proxmox-ring20-management")
    ev = env.explicit_circuit_evidence(f"{THEIRS}/ring20-manager", "h",
                                       runner=_runner(RING20), now_ms=NOW)
    assert ev["known"] is None
    assert any(f"{THEIRS}/proxmox-ring20-management" in k for k in ev["known_circuits"])


def test_same_name_with_another_circuit_is_a_contradiction(env):
    _learn(env, "ring20-dashboard", f"1389a831016c4bf1/ring20-dashboard")
    rows = [_row(f"inbox:{THEIRS}/ring20-dashboard", fetch=NOW - 1000)]
    ev = env.explicit_circuit_evidence(f"{THEIRS}/ring20-dashboard", "h",
                                       runner=_runner(rows), now_ms=NOW)
    assert ev["known"]                          # read here, so it may go …
    assert any("1389a831016c4bf1/ring20-dashboard" in k for k in ev["known_circuits"])  # … but say so


def test_own_hub_project_and_own_inbox_are_local_evidence(env):
    calls = []
    for cid in (f"{OWN}/{PROJECT}", f"{OWN}/010-termlink"):
        assert env.explicit_circuit_evidence(cid, None, runner=_runner([], calls),
                                             now_ms=NOW)["known"]
    assert calls == []


def test_unreadable_hub_is_no_evidence_and_says_so(env):
    ev = env.explicit_circuit_evidence(f"{THEIRS}/ring20-manager", "h",
                                       runner=_runner(RING20, rc=1), now_ms=NOW)
    assert ev["known"] is None and ev["hub_unreadable"]


# ── the send ─────────────────────────────────────────────────────────────────

@pytest.fixture()
def cli(env, monkeypatch):
    from lib import sidecar_cli as cli
    importlib.reload(cli)
    posted = []
    monkeypatch.setattr(cli.addressing, "resolve", lambda to, **k: {
        "circuit": to, "topic": f"inbox:{to}", "hub": k.get("hub"),
        "how": f"explicit circuit on hub {to.split('/')[0]}"})
    monkeypatch.setattr(cli.addressing, "hub_inbox_topics",
                        lambda hid, hub, runner=None: [r for r in RING20 if r["name"].startswith(f"inbox:{hid}/")])

    class R:
        client_msg_id, state, delivered, reason = "m1", "HUB_ACCEPTED", True, None
    monkeypatch.setattr(cli.delivery, "deliver", lambda *a, **k: posted.append(a) or R())
    cli.posted = posted
    return cli


def _outbox():
    from lib.sidecar import outbox
    return list(outbox._outbox_dir().glob("*.json"))


def test_send_to_unread_nickname_circuit_is_refused_naming_candidates(cli, capsys):
    rc = cli.main(["send", "--to", f"{THEIRS}/ring20-manager", "--hub", "ring20-manager",
                   "--body", "consult", "--json"])
    out = capsys.readouterr()
    assert rc == 2 and cli.posted == [] and not _outbox()
    assert json.loads(out.out.strip().splitlines()[-1])["state"] == "REFUSED"
    assert "proxmox-ring20-management" in out.err and "--force" in out.err


def test_send_with_force_goes_with_a_warning(cli, capsys):
    rc = cli.main(["send", "--to", f"{THEIRS}/ring20-manager", "--hub", "ring20-manager",
                   "--body", "consult", "--force"])
    err = capsys.readouterr().err
    assert rc == 0 and len(cli.posted) == 1
    assert "WARNING" in err and "proxmox-ring20-management" in err


def test_send_to_a_read_circuit_goes_silently(cli, capsys):
    rc = cli.main(["send", "--to", f"{THEIRS}/proxmox-ring20-management",
                   "--hub", "ring20-manager", "--body", "consult"])
    assert rc == 0 and len(cli.posted) == 1
    assert "WARNING" not in capsys.readouterr().err


def test_send_contradicting_peers_json_prints_the_known_circuit(cli, env, capsys):
    _learn(env, "proxmox-ring20-management", f"{THEIRS}/proxmox-ring20-management")
    cli.main(["send", "--to", f"{THEIRS}/ring20-manager", "--hub", "ring20-manager",
              "--body", "consult", "--force"])
    assert f"known circuit: proxmox-ring20-management -> {THEIRS}/proxmox-ring20-management" \
        in capsys.readouterr().err


# ── the receiving side: orphan inboxes on our own hub ────────────────────────

OWN_ROWS = [
    _row(f"inbox:{OWN}/ring20-manager", count=3, unread=NOW - DAY),          # orphan
    _row(f"inbox:{OWN}/{PROJECT}", count=9, unread=NOW - DAY),               # ours: read by us
    _row(f"inbox:{OWN}/010-termlink", count=9, unread=NOW - DAY),            # a fleet project
    _row(f"inbox:{OWN}/claude-shared", count=4, fetch=NOW - 1000),           # read since last write
    _row(f"inbox:{OWN}/empty-one", count=0, unread=None),                    # nothing in it
    _row(f"inbox:{OWN}/{PROJECT}/w4423", count=2, unread=NOW - DAY),         # a sub-agent's
]


def test_orphan_inboxes_names_only_unread_unknown_project_level_topics(env):
    rows = env.orphan_inboxes(runner=_runner(OWN_ROWS))
    assert [r["topic"] for r in rows] == [f"inbox:{OWN}/ring20-manager"]
    assert rows[0]["count"] == 3


def test_orphan_inboxes_skips_peer_directory_circuits(env):
    _learn(env, "ring20-manager", f"{OWN}/ring20-manager")
    assert env.orphan_inboxes(runner=_runner(OWN_ROWS)) == []


def test_orphan_inboxes_unreadable_hub_is_none_not_empty(env):
    assert env.orphan_inboxes(runner=_runner(OWN_ROWS, rc=1)) is None


def _fake_termlink(tmp_path, rows, rc=0):
    d = tmp_path / "fakebin"
    d.mkdir(exist_ok=True)
    (d / "rows.json").write_text(json.dumps({"topics": rows}))
    (d / "termlink").write_text(
        "#!/bin/sh\n"
        f'[ "$1 $2" = "channel list" ] || exit 9\n'
        f'cat "{d}/rows.json"\nexit {rc}\n')
    (d / "termlink").chmod(0o755)
    return d


def test_cli_orphan_inboxes_and_alerts_name_the_topic(env, tmp_path):
    d = _fake_termlink(tmp_path, OWN_ROWS)
    e = dict(os.environ, PATH=f"{d}{os.pathsep}{os.environ['PATH']}")
    cli = [sys.executable, str(FW_ROOT / "lib" / "sidecar_cli.py")]
    p = subprocess.run(cli + ["orphan-inboxes", "--json"], env=e, capture_output=True,
                       text=True, timeout=60)
    assert p.returncode == 1, p.stderr
    assert [r["topic"] for r in json.loads(p.stdout)] == [f"inbox:{OWN}/ring20-manager"]
    a = subprocess.run(cli + ["alerts"], env=e, capture_output=True, text=True, timeout=60)
    assert f"inbox:{OWN}/ring20-manager" in a.stdout, a.stdout + a.stderr


def test_doctor_audit_fact_source_reports_orphans_and_unreadable(env, tmp_path):
    def facts(rc):
        d = _fake_termlink(tmp_path, OWN_ROWS, rc=rc)
        return subprocess.run(
            ["bash", "-c", f'source "{FW_ROOT}/lib/sidecar-audit.sh"; '
                           f'fw_sidecar_orphan_inbox_facts "$PROJECT_ROOT"; echo "rc=$?"'],
            env=dict(os.environ, PATH=f"{d}{os.pathsep}{os.environ['PATH']}"),
            capture_output=True, text=True, timeout=120).stdout
    out = facts(0)
    assert f"inbox:{OWN}/ring20-manager\t3" in out and out.strip().endswith("rc=0")
    assert facts(1).strip().endswith("rc=2")


def test_doctor_and_audit_call_the_fact_source():
    for path in ("bin/fw", "agents/audit/audit.sh"):
        text = (FW_ROOT / path).read_text()
        assert "fw_sidecar_orphan_inbox_facts" in text and "T-4418" in text, path
