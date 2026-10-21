"""T-4530: a drain must not move the consult cursor past a post nothing took over.

Origin: 0909 (their G-002/T-1003) — `inbox:<hub>/0909-…` held 10 posts with no
receipts while `fw sidecar status` said 0 unread. `inbox.pending(advance=True)`
skipped any post the shown ledger said was shown (a peek, `alerts --mark-seen`)
and still moved the cursor past it, so the watcher never stored it and no
RECEIVED receipt went out. And a session reading a session-scoped circuit never
reads its own project address, which `orphan_inboxes` skipped as "a project".
The hub is faked throughout.
"""
from __future__ import annotations

import importlib
import json
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import inbox, receiver, seen  # noqa: E402

OWN = "cacc73ea32b121dd"
PROJECT = "t4530-proj"


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / PROJECT
    (root / ".context" / "sidecar").mkdir(parents=True)
    (root / ".framework.yaml").write_text(f"project_name: {PROJECT}\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", OWN)
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    for k in ("FW_SIDECAR_AGENT_ID", "TERMLINK_SESSION", "FW_FOCUS_SESSION_KEY",
              "RAIL_PROJECT_LABEL", "FW_RAIL_PROJECT_LABEL"):
        monkeypatch.delenv(k, raising=False)
    return root


def _env(offset, cmid):
    return {"offset": offset, "payload_b64": "",
            "metadata": {"client_msg_id": cmid, "from_agent": "peer-a"}}


def _reader(envs):
    def read(topic, cursor, limit=100):
        return [e for e in envs if e["offset"] >= cursor] if topic == inbox.inbox_topic() else []
    return read


def test_peeked_twice_post_is_returned_by_a_drain(proj):
    seen.mark_shown([("m-0", None)], by="peek")
    seen.mark_shown([("m-0", None)], by="peek")
    assert not seen.may_show({"m-0"})
    read = _reader([_env(0, "m-0")])
    assert inbox.pending(reader=read, advance=False) == []         # peeks stay quiet
    got = inbox.pending(reader=read, advance=True)
    assert [m["client_msg_id"] for m in got] == ["m-0"]             # the drain takes it over


def test_alert_marked_post_is_returned_by_a_drain(proj):
    seen.mark_shown([("m-1", {"client_msg_id": "m-1"})], by="alerts")
    got = inbox.pending(reader=_reader([_env(0, "m-1")]), advance=True)
    assert [m["client_msg_id"] for m in got] == ["m-1"]


def test_post_the_receiver_holds_is_still_stepped_over(proj):
    ok, err = receiver.store_message("m-2", {"client_msg_id": "m-2", "from": "peer-a",
                                              "conversation_id": "c", "body": "b"})
    assert ok, err
    seen.mark_shown([("m-2", {"client_msg_id": "m-2"})], by="hook")
    assert inbox.pending(reader=_reader([_env(0, "m-2")]), advance=True) == []
    assert inbox.load_state()["topics"][inbox.inbox_topic()]["cursor"] == 1


def test_peer_written_id_is_never_a_path(proj):
    assert inbox._held_by_receiver({"../../.framework"}, "t", 0) is False


# ── orphan_inboxes: our own project address ──────────────────────────────────

def _row(name, count, latest, unread_since=None):
    return {"name": name, "count": count, "latest_offset": latest,
            "activity": {"unread_since_ms": unread_since, "last_write_ms": 1,
                         "last_writer": "w"}}


class _Proc:
    def __init__(self, stdout):
        self.returncode, self.stdout, self.stderr = 0, stdout, ""


def _runner(rows):
    def run(argv, **kw):
        prefix = argv[argv.index("--prefix") + 1]
        return _Proc(json.dumps({"topics": [r for r in rows if r["name"].startswith(prefix)]}))
    return run


@pytest.fixture
def addressing(proj):
    import lib.sidecar.addressing as mod
    importlib.reload(mod)
    return mod


def test_own_project_inbox_unread_by_a_session_scoped_reader_is_named(proj, addressing, monkeypatch):
    monkeypatch.setenv("FW_FOCUS_SESSION_KEY", "S-1")
    topic = f"inbox:{OWN}/{PROJECT}"
    assert inbox.inbox_topic() != topic                    # this session reads another topic
    # 10 posts, and a fetch (a peek) already cleared the hub's unread marker
    rows = addressing.orphan_inboxes(runner=_runner([_row(topic, 10, 9, unread_since=None)]))
    assert [(r["topic"], r["count"], r["own_project"]) for r in rows] == [(topic, 10, True)]
    from lib import sidecar_cli
    assert "this project's address" in sidecar_cli._orphan_lines(rows)[0]


def test_own_project_inbox_drained_to_the_end_is_not_named(proj, addressing, monkeypatch):
    monkeypatch.setenv("FW_FOCUS_SESSION_KEY", "S-1")
    topic = f"inbox:{OWN}/{PROJECT}"
    state = inbox.load_state()
    state["topics"][topic] = {"cursor": 10}
    inbox.save_state(state)
    assert addressing.orphan_inboxes(runner=_runner([_row(topic, 10, 9)])) == []


def test_own_project_inbox_read_by_this_session_is_not_named(proj, addressing):
    topic = f"inbox:{OWN}/{PROJECT}"
    assert inbox.inbox_topic() == topic
    assert addressing.orphan_inboxes(runner=_runner([_row(topic, 10, 9)])) == []
