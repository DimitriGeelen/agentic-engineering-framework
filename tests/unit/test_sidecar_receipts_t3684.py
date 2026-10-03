"""T-3684 — receipts for consults that arrive on the hub topic (operator 2026-10-03).

The sender A and the receiver B are two scratch projects; A's receiver is a
REAL process (`fw sidecar receiver start --no-watcher`) spoken to over real
HTTP. The stand-ins are the hub (a recorded reader / runner): the live leg —
a real hub post picked up by B's real watcher — is in
tests/integration/t3684_sidecar_watcher_e2e_test.py (test_2, test_2b).
"""

from __future__ import annotations

import base64
import io
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import hooks, inbox, latency, outbox, receipts, receiver, watcher  # noqa: E402

CLI = [sys.executable, str(FW_ROOT / "lib" / "sidecar_cli.py")]


def _project(tmp_path, name):
    root = tmp_path / name
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text(f"project_name: {name}\n")
    return root


@pytest.fixture
def ab(tmp_path, monkeypatch):
    a, b = _project(tmp_path, "rcpt-a"), _project(tmp_path, "rcpt-b")
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)

    def use(root):
        monkeypatch.setenv("PROJECT_ROOT", str(root))
        monkeypatch.setenv("FW_SIDECAR_AGENT_ID", root.name)
    started = []

    def start(root):
        e = dict(os.environ, PROJECT_ROOT=str(root), FW_SIDECAR_AGENT_ID=root.name)
        p = subprocess.run(CLI + ["receiver", "start", "--no-watcher", "--agent", root.name],
                           cwd=root, env=e, capture_output=True, text=True, timeout=60)
        assert p.returncode == 0, p.stdout + p.stderr
        started.append(root)
    yield a, b, use, start
    for root in started:
        subprocess.run(CLI + ["receiver", "stop", "--quiet", "--agent", root.name], cwd=root,
                       env=dict(os.environ, PROJECT_ROOT=str(root)), capture_output=True, timeout=60)


def _hub_env(offset, cmid, frm, body="consult body", **meta):
    md = {"client_msg_id": cmid, "from_agent": frm, "conversation_id": "conv-r"}
    md.update(meta)
    return {"offset": offset, "ts": int(time.time() * 1000) - 2000,
            "payload_b64": base64.b64encode(body.encode()).decode(), "metadata": md}


class Hub:
    """The hub as both reader (for inbox.pending) and runner (for posts)."""

    def __init__(self):
        self.topics: dict[str, list[dict]] = {}
        self.posts: list[list[str]] = []

    def reader(self, topic, cursor, limit=100):
        return [e for e in self.topics.get(topic, []) if e["offset"] >= cursor]

    def runner(self, argv, **_):
        self.posts.append(argv)
        return subprocess.CompletedProcess(argv, 0, '{"delivered": {"offset": 0}}', "")


def _a_sends_over_hub(a, use, to="rcpt-b") -> str:
    use(a)
    return outbox.write_message(from_id="rcpt-a", to=to, body="q?", conversation_id="conv-r")


def test_received_handed_over_replied_reach_a_live_sender_receiver(ab, monkeypatch):
    a, b, use, start = ab
    start(a)
    cid = _a_sends_over_hub(a, use)
    # B's watcher takes it off the topic → RECEIVED to A at once (direct /ack)
    use(b)
    hub = Hub()
    monkeypatch.setattr(inbox, "read_topics", lambda agent=None: ["inbox:x/rcpt-b"])
    hub.topics["inbox:x/rcpt-b"] = [_hub_env(0, cid, "rcpt-a")]
    rep = watcher.ingest_hub(reader=hub.reader)
    assert rep["ingested"] == [cid]
    # HANDED_OVER: what the transcript-proven finalizer calls for a hub message
    hooks._confirm(cid, receiver.read_message(cid), "rcpt-b")
    # REPLIED: B's agent answers with --in-reply-to
    e = dict(os.environ, PROJECT_ROOT=str(b), FW_SIDECAR_AGENT_ID="rcpt-b")
    subprocess.run(CLI + ["send", "--to", "rcpt-a", "--body", "answer", "--conversation",
                          "conv-r", "--in-reply-to", cid, "--json"],
                   cwd=b, env=e, capture_output=True, text=True, timeout=60)
    sent = [(r["state"], r["via"], r["ok"]) for r in receipts.read_sent() if r["client_msg_id"] == cid]
    assert sent == [("RECEIVED", "direct", True), ("HANDED_OVER", "direct", True),
                    ("REPLIED", "direct", True)], sent
    use(a)
    got = [(r["state"], r["by"]) for r in receipts.read_ledger() if r["client_msg_id"] == cid]
    assert got == [("RECEIVED", "peer:rcpt-b"), ("HANDED_OVER", "peer:rcpt-b"),
                   ("REPLIED", "peer:rcpt-b")]
    m = [x for x in latency.report()["outbound"]["messages"] if x["client_msg_id"] == cid][0]
    assert m["path"] == "hub"
    assert 0 <= m["send_to_received_s"] <= m["send_to_handed_over_s"] <= m["send_to_replied_s"]


def test_receipt_sent_once_per_state(ab, monkeypatch):
    a, b, use, start = ab
    start(a)
    cid = _a_sends_over_hub(a, use)
    use(b)
    env = {"client_msg_id": cid, "from": "rcpt-a"}
    receipts.send(env, "RECEIVED", by="t")
    again = receipts.send(env, "RECEIVED", by="t")
    assert again["via"] == "already-sent"
    use(a)
    assert len([r for r in receipts.read_ledger() if r["state"] == "RECEIVED"]) == 1


def test_sender_refuses_receipts_for_ids_it_never_sent_or_from_the_wrong_peer(ab):
    a, b, use, start = ab
    cid = _a_sends_over_hub(a, use)
    assert receipts.record_from_peer("not-ours", "RECEIVED", "rcpt-b", via="t") is False
    assert receipts.record_from_peer(cid, "RECEIVED", "mallory", via="t") is False
    assert receipts.record_from_peer(cid, "PWNED", "rcpt-b", via="t") is False
    assert receipts.record_from_peer(cid, "RECEIVED", "rcpt-b", via="t") is True
    assert receipts.record_from_peer(cid, "RECEIVED", "rcpt-b", via="t") is False   # once


def test_no_live_sender_receiver_falls_back_to_the_hub_and_a_current_sender_records_it(ab, monkeypatch):
    a, b, use, start = ab
    cid = _a_sends_over_hub(a, use)          # A has NO receiver
    use(b)
    hub = Hub()
    monkeypatch.setattr(receipts.circuit, "topic_for_name", lambda name, **k: f"inbox:x/{name}")
    row = receipts.send({"client_msg_id": cid, "from": "rcpt-a", "conversation_id": "conv-r"},
                        "RECEIVED", by="watcher", runner=hub.runner)
    assert row["ok"] and row["via"] == "hub:inbox:x/rcpt-a"
    argv = hub.posts[0]
    assert "sidecar.receipt" in argv and "kind=receipt" in argv and f"receipt_for={cid}" in argv
    # A (a current install) reads its inbox: the receipt is recorded, never a consult
    use(a)
    md = {argv[i + 1].split("=", 1)[0]: argv[i + 1].split("=", 1)[1]
          for i, x in enumerate(argv) if x == "--metadata"}
    receipt_env = {"offset": 0, "ts": 1, "payload_b64": base64.b64encode(b"r").decode(),
                   "metadata": md}
    monkeypatch.setattr(inbox, "read_topics", lambda agent=None: ["inbox:x/rcpt-a"])
    consults = inbox.pending(reader=lambda t, c, limit=100: [receipt_env] if c == 0 else [])
    assert consults == []
    assert [(r["state"], r["via"]) for r in receipts.read_ledger()] == [("RECEIVED", "hub:inbox:x/rcpt-a")]


def test_inbox_drain_sends_received_and_handed_over(ab, monkeypatch):
    a, b, use, start = ab
    start(a)
    cid = _a_sends_over_hub(a, use)
    use(b)
    sent = []
    monkeypatch.setattr(receipts, "send", lambda m, st, by, **k: sent.append((m["client_msg_id"], st, by)))
    monkeypatch.setattr(inbox, "pending", lambda advance=True, **k:
                        [{"client_msg_id": cid, "from": "rcpt-a", "body": "q"}])
    from lib import sidecar_cli
    sidecar_cli.cmd_inbox(type("A", (), {"peek": False, "json": True, "receipt": False})())
    assert sent == [(cid, "RECEIVED", "inbox-cli"), (cid, "HANDED_OVER", "inbox-cli")]


def test_prompt_hook_peek_sends_received_detached(ab, monkeypatch):
    a, b, use, start = ab
    use(b)
    queued = []
    monkeypatch.setattr(receipts, "send_detached", lambda ms, states, by: queued.append((len(ms), states, by)))
    monkeypatch.setattr(inbox, "pending", lambda advance=True, **k:
                        [{"client_msg_id": "x1", "from": "rcpt-a", "body": "q"}])
    monkeypatch.setattr(sys.modules["lib.sidecar_cli"].dm, "summary", lambda: [])
    from lib import sidecar_cli
    sidecar_cli.cmd_inbox(type("A", (), {"peek": True, "json": True, "receipt": True})())
    assert queued == [(1, ["RECEIVED"], "prompt-hook-peek")]
    assert "--peek --receipt --json" in (FW_ROOT / "agents/context/sidecar-inbox.sh").read_text()


def test_detached_flush_sends(ab, monkeypatch):
    a, b, use, start = ab
    start(a)
    cid = _a_sends_over_hub(a, use)
    use(b)
    receipts.send_detached([{"client_msg_id": cid, "from": "rcpt-a"}], ["RECEIVED"], by="peek")
    use(a)
    deadline = time.time() + 20
    while time.time() < deadline and not receipts.read_ledger():
        time.sleep(0.2)
    assert [r["state"] for r in receipts.read_ledger()] == ["RECEIVED"]
