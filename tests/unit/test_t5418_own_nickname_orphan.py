"""T-5418: an orphan inbox named like THIS project is mail to us that nobody reads.

T-5416: inbox:<hub>/agentic-engineering-framework (this project's id without its numeric
prefix — what peers derive from the repository name) held 10 posts for up to a month, and
the alert showed it as one anonymous count line among unrelated orphans. Now it is reported
first, with senders, ages and the fix. Hermetic: hub, reader and readers check are faked.
"""
from __future__ import annotations

import importlib
import sys
import time
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

OWN = "cacc73ea32b121dd"
PROJECT = "999-Agentic-Engineering-Framework"
NOW = int(time.time() * 1000)
DAY = 86_400_000


@pytest.fixture()
def env(tmp_path, monkeypatch):
    proj = tmp_path / PROJECT
    (proj / ".context" / "sidecar").mkdir(parents=True)
    (proj / ".framework.yaml").write_text("project: x\n")
    monkeypatch.setenv("PROJECT_ROOT", str(proj))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", OWN)
    for k in ("FW_SIDECAR_AGENT_ID", "TERMLINK_SESSION", "FW_FOCUS_SESSION_KEY",
              "RAIL_PROJECT_LABEL", "FW_RAIL_PROJECT_LABEL", "FW_SIDECAR_INBOX_ALIASES"):
        monkeypatch.delenv(k, raising=False)
    import lib.sidecar.addressing as addressing
    importlib.reload(addressing)
    import lib.sidecar_cli as cli
    importlib.reload(cli)
    return addressing, cli


def _topics(monkeypatch, addressing, names):
    rows = [{"name": n, "count": 3, "latest_offset": 2,
             "activity": {"last_write_ms": NOW - DAY, "unread_since_ms": NOW - DAY}} for n in names]
    monkeypatch.setattr(addressing, "hub_inbox_topics", lambda own, hub, runner: rows)
    from lib.sidecar import inbox
    monkeypatch.setattr(inbox, "inbox_readers", lambda topic, runner=None: ("none", ""))
    monkeypatch.setattr(addressing, "load_peers", lambda: {"peers": {}})


def test_own_nicknames_are_the_id_and_the_id_without_prefix(env):
    addressing, _ = env
    assert addressing.own_nicknames() == {"999-agentic-engineering-framework",
                                         "agentic-engineering-framework"}


def test_orphan_named_like_this_project_is_flagged_and_a_foreign_one_is_not(env, monkeypatch):
    addressing, _ = env
    _topics(monkeypatch, addressing, [f"inbox:{OWN}/agentic-engineering-framework",
                                      f"inbox:{OWN}/somebody-else"])
    rows = {r["topic"].rsplit("/", 1)[-1]: r for r in addressing.orphan_inboxes()}
    assert rows["agentic-engineering-framework"]["own_nickname"] is True
    assert rows["agentic-engineering-framework"]["first_unacked"] == 0
    assert rows["somebody-else"]["own_nickname"] is False


def test_an_aliased_nickname_is_read_and_never_reported(env, monkeypatch):
    addressing, _ = env
    monkeypatch.setenv("FW_SIDECAR_INBOX_ALIASES", "agentic-engineering-framework")
    _topics(monkeypatch, addressing, [f"inbox:{OWN}/agentic-engineering-framework"])
    assert addressing.orphan_inboxes() == []


def test_alert_reports_own_nickname_first_with_senders_ages_and_the_fix(env):
    _, cli = env
    orphans = [
        {"topic": f"inbox:{OWN}/somebody-else", "count": 4},
        {"topic": f"inbox:{OWN}/agentic-engineering-framework", "count": 2, "own_nickname": True,
         "first_unacked": 0},
    ]
    senders = lambda o: [{"from": "0909-boot-into-timeshift-snapshots", "conversation": "watchtower-file-links-0909",
                          "age_s": 35 * 86400},
                         {"from": "150-skills-manager", "conversation": "C-010", "age_s": 7200}]
    lines = cli._orphan_lines(orphans, senders)
    assert lines[0].startswith("MAIL TO THIS PROJECT NOBODY READS: 2 post(s)")
    assert "'agentic-engineering-framework'" in lines[0]
    assert "  - from 0909-boot-into-timeshift-snapshots, 35d ago, conversation watchtower-file-links-0909" in lines
    assert "  - from 150-skills-manager, 2h ago, conversation C-010" in lines
    fix = [l for l in lines if l.startswith("  fix: ")][0]
    assert "config set SIDECAR_INBOX_ALIASES agentic-engineering-framework" in fix and "cd " in fix
    assert any("sidecar inbox --mark-read agentic-engineering-framework" in l for l in lines)
    # the own-nickname topic is not repeated as an anonymous orphan; the foreign one keeps its line
    anon = [l for l in lines if l.startswith("orphan inbox:")]
    assert len(anon) == 1 and "somebody-else" in anon[0]


def test_unreadable_topic_says_not_checked_and_hub_down_is_unchanged(env):
    _, cli = env
    o = [{"topic": f"inbox:{OWN}/agentic-engineering-framework", "count": 1, "own_nickname": True}]
    assert "  senders: NOT CHECKED (the topic could not be read)" in cli._orphan_lines(o, lambda o: None)
    assert cli._orphan_lines(None) == ["orphan inboxes: NOT CHECKED (the hub could not be asked)"]


def test_topic_senders_reads_metadata_and_keeps_the_last_five(env):
    addressing, _ = env
    env_ = [{"ts": NOW - (10 - i) * 1000, "metadata": {"from_project": f"p{i}", "conversation_id": f"c{i}"}}
            for i in range(8)]
    got = addressing.topic_senders("t", 0, 5, reader=lambda topic, cur, lim: env_, now_ms=NOW)
    assert [g["from"] for g in got] == ["p3", "p4", "p5", "p6", "p7"]
    assert got[-1]["age_s"] == 3 and got[-1]["conversation"] == "c7"
    assert addressing.topic_senders("t", reader=lambda *a: "failed") is None
