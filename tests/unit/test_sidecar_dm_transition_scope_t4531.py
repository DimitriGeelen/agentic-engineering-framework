"""T-4531: `fw sidecar inbox` must not drain the host-shared dm rails a T-4311 transition keeps in view.

Origin: 0909 (own identity, SIDECAR_HOST_DM_TRANSITION on by default) ran a plain
`fw sidecar inbox` and was shown the content of dm-rail posts addressed to 055 and 832.
The T-4252 guard only asked whether OUR key is the host key; the transition added the
host key to the rail set beside our own, so those rails were drained anyway. The hub is
a fake `termlink` on PATH (the T-4311 fixture); nothing reaches a real hub.
"""
import json
import sys
from argparse import Namespace
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import sidecar_cli  # noqa: E402
from lib.sidecar import dm, identity, inbox  # noqa: E402
from test_sidecar_rail_identity_t4311 import (  # noqa: E402,F401  (fixture import)
    HOST_FP, OWN_FP, _configure, project)

HOST_RAIL = {"name": f"dm:peer:{HOST_FP}", "count": 5, "latest_offset": 4}
OWN_RAIL = {"name": f"dm:peer:{OWN_FP}", "count": 5, "latest_offset": 4}
TOPICS = json.dumps({"topics": [HOST_RAIL, OWN_RAIL]})


def _switch(project, monkeypatch):
    _configure(project)
    assert identity.apply() is not None
    assert dm.legacy_host_fingerprint() == HOST_FP
    monkeypatch.setenv("FAKE_TL_TOPICS", TOPICS)


def test_pending_never_drains_host_rail(project, monkeypatch):
    _switch(project, monkeypatch)
    got = dm.pending(advance=True)
    assert {p["topic"] for p in got} == {OWN_RAIL["name"]}
    topics = inbox.load_state()["topics"]
    assert HOST_RAIL["name"] not in topics             # no cursor written for it
    assert topics[OWN_RAIL["name"]]["cursor"] == 5


def test_shared_summary_lists_only_host_rail(project, monkeypatch):
    _switch(project, monkeypatch)
    rows = dm.shared_summary()
    assert [(r["topic"], r["unread"]) for r in rows] == [(HOST_RAIL["name"], 5)]


def test_no_transition_no_shared_rows(project, monkeypatch):
    _configure(project)
    identity.apply()
    monkeypatch.setenv("FW_SIDECAR_HOST_DM_TRANSITION", "0")
    monkeypatch.setenv("FAKE_TL_TOPICS", TOPICS)
    assert dm.shared_summary() == []


def test_cli_plain_inbox_shows_host_rail_as_summary(project, monkeypatch, capsys):
    """The regression: plain inbox, own identity, transition on — no host-rail content, no cursor."""
    _switch(project, monkeypatch)
    monkeypatch.setattr(inbox, "inbox_topic", lambda *a, **k: "inbox:x")
    assert sidecar_cli._print_inbox(Namespace(peek=False, json=True), []) == 0
    data = json.loads(capsys.readouterr().out)
    assert {p["topic"] for p in data["dm_posts"]} == {OWN_RAIL["name"]}
    assert [r["topic"] for r in data["dm_rails"]] == [HOST_RAIL["name"]]
    assert "SIDECAR_HOST_DM_TRANSITION" in data["dm_drain_refused"]
    assert HOST_RAIL["name"] not in inbox.load_state()["topics"]
