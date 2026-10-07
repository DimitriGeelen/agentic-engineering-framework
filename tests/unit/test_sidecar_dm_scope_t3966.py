"""T-3966: `fw sidecar inbox` says that dm rails are host-wide.

DM rails are keyed by `termlink whoami`, the host's identity, shared by every project on
the machine. Reading them stays (T-3442); the output now says a dm may be meant for
another project. The hub is never called here: dm.summary / dm.pending are faked.
"""
import json
import sys
from argparse import Namespace
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import sidecar_cli  # noqa: E402

POST = {"offset": 3, "topic": "dm:aaaa:bbbb", "from": "peer", "body": "hello", "ts": "t"}
RAIL = {"topic": "dm:aaaa:bbbb", "count": 4, "cursor": 3, "unread": 1}


def _run(monkeypatch, capsys, *, peek, json_out, rails=(), posts=()):
    monkeypatch.setattr(sidecar_cli.dm, "summary", lambda *a, **k: list(rails))
    monkeypatch.setattr(sidecar_cli.dm, "pending", lambda *a, **k: list(posts))
    monkeypatch.setattr(sidecar_cli.inbox, "inbox_topic", lambda *a, **k: "inbox:x")
    rc = sidecar_cli._print_inbox(Namespace(peek=peek, json=json_out), [])
    assert rc == 0
    return capsys.readouterr().out


def test_text_dm_posts_carry_the_host_wide_note(monkeypatch, capsys):
    out = _run(monkeypatch, capsys, peek=False, json_out=False, posts=[POST])
    assert out.index("NOTE: dm rails are keyed by this host") < out.index("--- dm @3")


def test_peek_rail_summaries_carry_the_note(monkeypatch, capsys):
    out = _run(monkeypatch, capsys, peek=True, json_out=False, rails=[RAIL])
    assert "another project" in out and "dm rail dm:aaaa:bbbb" in out


def test_json_both_forms(monkeypatch, capsys):
    for peek, kw in ((False, {"posts": [POST]}), (True, {"rails": [RAIL]})):
        data = json.loads(_run(monkeypatch, capsys, peek=peek, json_out=True, **kw))
        assert data["dm_scope"] == "host-identity"
        assert "another project" in data["dm_scope_note"]


def test_control_no_dm_no_note(monkeypatch, capsys):
    out = _run(monkeypatch, capsys, peek=False, json_out=False)
    assert "NOTE" not in out and "no pending consults" in out
    data = json.loads(_run(monkeypatch, capsys, peek=False, json_out=True))
    assert "dm_scope" not in data
