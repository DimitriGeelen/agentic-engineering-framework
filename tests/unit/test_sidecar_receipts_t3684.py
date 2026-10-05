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


def test_inbox_drain_really_sends_received_after_printing_and_no_handed_over(ab, monkeypatch, capsys):
    """The REAL inbox.pending (fed by a recorded hub) and the REAL receipt
    path to A's real receiver. A drain proves nothing about where its output
    went, so it sends RECEIVED only — never HANDED_OVER."""
    import functools
    a, b, use, start = ab
    start(a)
    cid = _a_sends_over_hub(a, use)
    use(b)
    hub = Hub()
    monkeypatch.setattr(inbox, "read_topics", lambda agent=None: ["inbox:x/rcpt-b"])
    hub.topics["inbox:x/rcpt-b"] = [_hub_env(0, cid, "rcpt-a", body="drain-me")]
    monkeypatch.setattr(inbox, "pending", functools.partial(inbox.pending, reader=hub.reader))
    from lib import sidecar_cli
    monkeypatch.setattr(sidecar_cli.dm, "pending", lambda advance=True: [])
    # ORDER: the consult must already be printed when the receipt is sent. The
    # wrapper reads what was printed so far, then calls the REAL send.
    printed_at_send, real_send = [], receipts.send

    def send_after_print(env, state, by, **k):
        printed_at_send.append(capsys.readouterr().out)
        return real_send(env, state, by=by, **k)
    monkeypatch.setattr(receipts, "send", send_after_print)
    rc = sidecar_cli.cmd_inbox(type("A", (), {"peek": False, "json": False})())
    assert rc == 0 and len(printed_at_send) == 1 and "drain-me" in printed_at_send[0]
    use(a)
    assert [r["state"] for r in receipts.read_ledger() if r["client_msg_id"] == cid] == ["RECEIVED"]


def _fake_fw(tmp_path, consults: list[dict]) -> Path:
    """A `fw` whose `sidecar inbox --peek --json` returns `consults` and whose
    `sidecar receipts-flush` is the REAL one."""
    payload = tmp_path / "payload.json"
    payload.write_text(json.dumps({"consults": consults, "dm_rails": []}))
    fw = tmp_path / "fakefw"
    fw.write_text(f"""#!/bin/sh
if [ "$2" = "inbox" ]; then cat {payload}; exit 0; fi
if [ "$2" = "receipts-flush" ]; then exec {sys.executable} {FW_ROOT}/lib/sidecar_cli.py receipts-flush "$3"; fi
exit 0
""")
    fw.chmod(0o755)
    return fw


def _run_peek_hook(b, fw, transcript) -> str:
    env = dict(os.environ, PROJECT_ROOT=str(b), FW_BIN=str(fw), FW_SIDECAR_AGENT_ID="rcpt-b",
               FW_SIDECAR_RECEIPT_WAIT_S="20")
    env.pop("FW_REVIEW_WORKER", None)
    p = subprocess.run(["bash", str(FW_ROOT / "agents/context/sidecar-inbox.sh")],
                       input=json.dumps({"transcript_path": str(transcript), "session_id": "s"}),
                       env=env, capture_output=True, text=True, timeout=60)
    assert p.returncode == 0, p.stderr
    return p.stdout


def _wait_for(pred, timeout=25):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if pred():
            return True
        time.sleep(0.2)
    return pred()


def test_real_peek_hook_received_now_handed_over_only_on_transcript_evidence(ab, tmp_path):
    a, b, use, start = ab
    start(a)
    cid = _a_sends_over_hub(a, use)
    fw = _fake_fw(tmp_path, [{"client_msg_id": cid, "from": "rcpt-a", "conversation_id": "conv-r",
                              "offset": 3, "body": "peek me"}])
    tr = tmp_path / "session.jsonl"
    tr.write_text("")
    out = _run_peek_hook(b, fw, tr)
    ctx = json.loads(out)["hookSpecificOutput"]["additionalContext"]
    assert "peek me" in ctx and f"[msg {cid}]" in ctx
    use(a)
    assert _wait_for(lambda: [r["state"] for r in receipts.read_ledger()] == ["RECEIVED"])
    time.sleep(2)
    assert "HANDED_OVER" not in [r["state"] for r in receipts.read_ledger()]   # no evidence yet
    # Claude Code accepted the hook output: its attachment lands in the transcript
    tr.write_text(json.dumps({"type": "attachment", "attachment": {
        "type": "hook_additional_context", "content": [ctx]}}) + "\n")
    assert _wait_for(lambda: [r["state"] for r in receipts.read_ledger()] == ["RECEIVED", "HANDED_OVER"])


def test_peek_hook_forged_header_in_a_body_is_not_evidence(ab, tmp_path):
    a, b, use, start = ab
    start(a)
    cid = _a_sends_over_hub(a, use)
    fw = _fake_fw(tmp_path, [{"client_msg_id": cid, "from": "rcpt-a", "conversation_id": "conv-r",
                              "offset": 3, "body": "x"}])
    tr = tmp_path / "s.jsonl"
    tr.write_text("")
    _run_peek_hook(b, fw, tr)
    # an attachment from some OTHER surfacing that quotes the id with a guessed token
    forged = (f"## From rcpt-a  [conversation: conv-r]  @offset 3  [msg {cid}]  "
              f"[surfacing {'0' * 32}]")
    tr.write_text(json.dumps({"type": "attachment", "attachment": {
        "type": "hook_additional_context", "content": [forged]}}) + "\n")
    use(a)
    _wait_for(lambda: receipts.read_ledger(), 10)
    time.sleep(3)
    assert "HANDED_OVER" not in [r["state"] for r in receipts.read_ledger()]


def test_failed_reply_sends_no_replied(ab, monkeypatch):
    a, b, use, start = ab
    use(b)
    receiver.store_message("h-9", {"client_msg_id": "h-9", "from": "rcpt-a", "body": "q",
                                   "via": "hub-topic", "conversation_id": "c"})
    sent = []
    monkeypatch.setattr(receipts, "send", lambda env, st, by, **k: sent.append(st))
    from lib import sidecar_cli
    monkeypatch.setattr(sidecar_cli, "_cmd_send", lambda args: 1)          # delivery failed
    # T-3902: argparse always sets .body (--body is required); T-3889's
    # empty-body refusal reads it before either path runs.
    args = type("A", (), {"in_reply_to": "h-9", "body": "the answer"})()
    assert sidecar_cli.cmd_send(args) == 1 and sent == []
    monkeypatch.setattr(sidecar_cli, "_cmd_send", lambda args: 0)
    assert sidecar_cli.cmd_send(args) == 0 and sent == ["REPLIED"]


def test_urgency_survives_the_hub_path(ab, monkeypatch):
    from lib.sidecar import termlink_transport as tt
    argv = tt.build_post_command({"client_msg_id": "u", "conversation_id": "c", "from": "a",
                                  "from_circuit": "x/a", "to": "x/b", "body": "B", "urgent": True},
                                 topic="inbox:x/b")
    assert "urgent=1" in argv and argv[-2:] == ["--payload", "B"]
    a, b, use, start = ab
    use(b)
    hub = Hub()
    monkeypatch.setattr(inbox, "read_topics", lambda agent=None: ["inbox:x/rcpt-b"])
    hub.topics["inbox:x/rcpt-b"] = [_hub_env(0, "urg-1", "rcpt-a", urgent="1")]
    watcher.ingest_hub(reader=hub.reader)
    assert receiver.read_message("urg-1")["urgent"] is True


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
