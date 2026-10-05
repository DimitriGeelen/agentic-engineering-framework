"""T-3856 — `fw sidecar alerts`, the shipped /resume step-7 mail check.

The project-local script it replaces was absent in every consumer and in this
repo, so the check skipped silently exactly where it mattered. The contract
pinned here: both mail routes, each message once, read-only unless
--mark-seen, and NOT CHECKED (never an empty answer) when a route is unreadable.
"""

from __future__ import annotations

import base64
import hashlib
import io
import subprocess
import sys
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, alerts, inbox, outbox, receiver, seen  # noqa: E402
import lib.sidecar_cli as cli  # noqa: E402


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "t3856"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t3856\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.delenv("FW_REVIEW_WORKER", raising=False)
    monkeypatch.setattr(adapter, "_claude_ancestor_pid", lambda *a, **k: None)
    return root


def _env(offset, mid, body, sender="832-Workflow-designer", conv="c1"):
    return {"offset": offset, "ts": 1791200000000 + offset, "msg_type": "sidecar.consult",
            "payload_b64": base64.b64encode(body.encode()).decode(),
            "metadata": {"client_msg_id": mid, "from_agent": sender, "conversation_id": conv}}


def _hub(envs):
    """A reader that serves `envs` on the primary inbox topic only."""
    def reader(topic, cursor, limit=50, **_):
        if topic != inbox.inbox_topic():
            return []
        return [e for e in envs if e["offset"] >= cursor][:limit]
    return reader


def _store(mid, body="stored body"):
    env = {"client_msg_id": mid, "from": "010-termlink", "conversation_id": "c2", "body": body}
    assert receiver.store_message(mid, env)[0]


def _ledger_bytes(root):
    files = sorted((root / ".context").rglob("*.json"))
    return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files
            if "seen" in p.name or "inbox-state" in p.name}


def test_lists_both_routes_each_once(proj):
    _store("r-1")
    rows = alerts.collect(reader=_hub([_env(0, "h-1", "first line\nmore"),
                                       _env(1, "h-1", "first line\nmore")]))
    assert [(r["route"], r["id"]) for r in rows] == [("hub", "h-1"), ("receiver", "r-1")]
    assert rows[0]["first_line"] == "first line"
    assert rows[0]["from"] == "832-Workflow-designer"


def test_answered_and_withheld_mail_is_not_listed(proj):
    _store("m-base-nudge-4")
    outbox.write_message(from_id="me", to="832-Workflow-designer", body="answered",
                         conversation_id="c1", in_reply_to="m-base")
    outbox.write_message(from_id="me", to="832-Workflow-designer", body="answered",
                         conversation_id="c1", in_reply_to="h-ans")
    assert alerts.collect(reader=_hub([_env(0, "h-ans", "x")])) == []


def test_read_only_unless_mark_seen(proj):
    _store("r-1")
    reader = _hub([_env(0, "h-1", "x")])
    seen.mark_shown([("unrelated", None)], by="hook")  # a real, non-empty ledger
    before = _ledger_bytes(proj)
    assert before, "ledger must exist, or 'unchanged' proves nothing"
    assert len(alerts.collect(reader=reader)) == 2
    assert _ledger_bytes(proj) == before
    alerts.mark_seen(alerts.collect(reader=reader))     # control: this one writes
    assert _ledger_bytes(proj) != before
    assert alerts.collect(reader=reader) == []          # and is not repeated


def test_unreadable_hub_raises_never_empty(proj, monkeypatch):
    monkeypatch.setattr(inbox, "_binary", lambda: "termlink-does-not-exist")
    with pytest.raises(alerts.Unreadable, match="not found"):
        alerts.collect()


def test_strict_reader_hub_error_is_unreadable_but_unknown_topic_is_empty(proj, monkeypatch):
    monkeypatch.setattr(inbox, "_binary", lambda: "/bin/termlink-fake")
    out = {"rc": 1, "err": "JSON-RPC error -32013: unknown topic 'inbox:x'"}
    monkeypatch.setattr(subprocess, "run", lambda *a, **k: subprocess.CompletedProcess(
        a, out["rc"], "", out["err"]))
    assert alerts.strict_reader("inbox:x", 0) == []
    out["err"] = "connection refused"
    with pytest.raises(alerts.Unreadable, match="connection refused"):
        alerts.strict_reader("inbox:x", 0)


def test_cli_prints_not_checked_and_exits_3(proj, monkeypatch):
    def boom(**_):
        raise alerts.Unreadable("hub down")
    monkeypatch.setattr(alerts, "collect", boom)
    buf = io.StringIO()
    with redirect_stdout(buf):
        rc = cli.cmd_alerts(SimpleNamespace(limit=10, json=False, mark_seen=False))
    assert rc == 3 and buf.getvalue().strip() == "NOT CHECKED: hub down"


def test_cli_says_nothing_unseen_explicitly(proj, monkeypatch):
    monkeypatch.setattr(alerts, "collect", lambda **_: [])
    buf = io.StringIO()
    with redirect_stdout(buf):
        rc = cli.cmd_alerts(SimpleNamespace(limit=10, json=False, mark_seen=False))
    assert rc == 0 and "nothing unseen" in buf.getvalue()
