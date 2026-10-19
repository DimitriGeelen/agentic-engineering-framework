"""T-4348 — `fw sidecar send --notice`: delivered and surfaced like any message,
never counted as awaiting a reply.

ring20 (msg a3f8780f) dropped 23 FYI/status/thank-you sends the sidecar had
chased for 1-12 days: re-posts, inbox nudges, operator pushes. Every send was a
consult. These tests pin the notice kind on each reply tracker (hub retry
ladder, direct hand-over escalation, waiting register) against a non-notice
control, and the receiver-side label. All state lives in a temp PROJECT_ROOT;
the live sidecar is never touched (T-4315).
"""

import importlib
from datetime import datetime, timedelta, timezone

import pytest

T0 = datetime(2026, 10, 19, 12, 0, 0, tzinfo=timezone.utc)


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    (tmp_path / ".context").mkdir()
    (tmp_path / ".framework.yaml").write_text("project_name: notice-a\n")
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "notice-a")
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_HOST", "host107.ring20.lan")
    for k in ("FW_SIDECAR_CONSULT_WARN_HOURS", "NTFY_ENABLED", "FW_SIDECAR_NOTIFY_CMD"):
        monkeypatch.delenv(k, raising=False)
    from lib.sidecar import (delivery, direct, hooks, inbox, outbox, receipts, receiver,
                             retry, termlink_transport, waiting)
    import lib.sidecar_cli as cli
    for m in (outbox, delivery, inbox, retry, receipts, receiver, direct, waiting,
              termlink_transport, hooks, cli):
        importlib.reload(m)
    return {"cli": cli, "outbox": outbox, "delivery": delivery, "retry": retry,
            "direct": direct, "waiting": waiting, "hooks": hooks, "inbox": inbox,
            "receiver": receiver, "tl": termlink_transport}


def _ok_probe(_hub):
    from lib.sidecar import delivery
    return delivery.ProbeResult(True)


def _empty_reader(_topic, _cursor, _limit=None):
    return []


def _hub_send(m, *, notice, at=T0):
    cmid = m["outbox"].write_message(from_id="notice-a", to="agentB", body="fyi: done",
                                     conversation_id="conv-n", notice=notice)
    m["delivery"].deliver(cmid, lambda _msg: None, _ok_probe, now=at)
    return cmid


# ── send verb ────────────────────────────────────────────────────────────────

def test_send_parser_has_notice_flag_documented(sc):
    parser = sc["cli"].build_parser()
    args = parser.parse_args(["send", "--to", "agentB", "--body", "x", "--notice"])
    assert args.notice is True
    assert parser.parse_args(["send", "--to", "agentB", "--body", "x"]).notice is False
    send = next(a for a in parser._subparsers._group_actions[0].choices.items() if a[0] == "send")[1]
    assert "no reply expected" in send.format_help().lower()


def test_outbox_and_hub_post_carry_notice_only_when_set(sc):
    ob, tl = sc["outbox"], sc["tl"]
    n = ob.write_message(from_id="notice-a", to="agentB", body="b", conversation_id="c",
                         notice=True)
    c = ob.write_message(from_id="notice-a", to="agentB", body="b", conversation_id="c")
    msg_n, msg_c = sc["delivery"].read_message(n), sc["delivery"].read_message(c)
    assert msg_n.get("notice") is True
    assert "notice" not in msg_c        # an ordinary send's shape is unchanged
    argv_n = tl.build_post_command(dict(msg_n, from_circuit="x"), binary="termlink", topic="t")
    argv_c = tl.build_post_command(dict(msg_c, from_circuit="x"), binary="termlink", topic="t")
    assert "notice=1" in argv_n and "notice=1" not in argv_c


# ── hub path: retry ladder ──────────────────────────────────────────────────

def test_posted_notice_leaves_the_ladder_and_is_never_nudged(sc):
    ob, retry = sc["outbox"], sc["retry"]
    note = _hub_send(sc, notice=True)
    ctrl = _hub_send(sc, notice=False)
    assert not retry.is_open(ob.latest_ack_state(note))
    assert (ob.latest_ack_state(note).get("error") or "").startswith(retry.NOTICE)
    assert retry.is_open(ob.latest_ack_state(ctrl))
    nudged = []
    report = retry.sweep(now=T0 + timedelta(days=40), transport=lambda _m: None,
                         probe=_ok_probe, reader=_empty_reader,
                         nudge=lambda msg, *a, **k: nudged.append(msg["client_msg_id"]) or "x",
                         operator_notice=lambda msg, *a, **k: nudged.append(msg["client_msg_id"]) or "x")
    acted = {a["client_msg_id"] for a in report["actions"]}
    assert note not in acted and note not in nudged
    assert ctrl in acted                 # the control is still chased


def test_unposted_notice_is_still_delivered_then_closes(sc):
    ob, delivery, retry = sc["outbox"], sc["delivery"], sc["retry"]
    cmid = ob.write_message(from_id="notice-a", to="agentB", body="fyi",
                            conversation_id="conv-n", notice=True)

    def boom(_m):
        raise delivery.TransportError("hub down")
    delivery.deliver(cmid, boom, _ok_probe, now=T0)
    assert retry.is_open(ob.latest_ack_state(cmid))     # delivery is still owed
    posted = []
    retry.sweep(now=T0 + timedelta(hours=2), transport=posted.append, probe=_ok_probe,
                reader=_empty_reader)
    assert [p["client_msg_id"] for p in posted] == [cmid]
    assert not retry.is_open(ob.latest_ack_state(cmid))


# ── direct path: hand-over escalation ───────────────────────────────────────

def _direct_send(sc, monkeypatch, *, notice):
    d = sc["direct"]
    seen = []

    def fake_post(entry, path, payload, token=None):
        seen.append(payload)
        return 200, {"status": d.RECEIVED}
    monkeypatch.setattr(d, "post_with_token", fake_post)
    row = d.send({"url": "http://127.0.0.1:1"}, from_id="notice-a", to="agentB",
                 body="fyi", conversation_id="conv-d", notice=notice)
    return row, seen[-1]


def test_direct_notice_is_terminal_at_received(sc, monkeypatch):
    d = sc["direct"]
    row_n, env_n = _direct_send(sc, monkeypatch, notice=True)
    row_c, env_c = _direct_send(sc, monkeypatch, notice=False)
    assert env_n.get("notice") is True and "notice" not in env_c
    assert row_n["state"] == d.RECEIVED and not row_n.get("deadline")
    flipped = d.escalate_expired((datetime.now(timezone.utc) + timedelta(days=3)).isoformat())
    assert row_n["client_msg_id"] not in flipped
    assert row_c["client_msg_id"] in flipped


# ── waiting register: warn/overdue listing ──────────────────────────────────

def test_delivered_notice_is_not_listed_as_waiting(sc, monkeypatch):
    w = sc["waiting"]
    w.epoch()
    row_n, _ = _direct_send(sc, monkeypatch, notice=True)
    row_c, _ = _direct_send(sc, monkeypatch, notice=False)
    hub_n = _hub_send(sc, notice=True, at=datetime.now(timezone.utc))
    hub_c = _hub_send(sc, notice=False, at=datetime.now(timezone.utc))
    later = datetime.now(timezone.utc) + timedelta(hours=30)
    ids = {i["id"] for i in w.outbound_items(later)}
    assert row_n["client_msg_id"] not in ids and hub_n not in ids
    assert row_c["client_msg_id"] in ids and hub_c in ids


def test_undelivered_hub_notice_is_still_listed(sc):
    w, ob, delivery = sc["waiting"], sc["outbox"], sc["delivery"]
    w.epoch()
    cmid = ob.write_message(from_id="notice-a", to="agentB", body="fyi",
                            conversation_id="conv-n", notice=True)

    def boom(_m):
        raise delivery.TransportError("hub down")
    delivery.deliver(cmid, boom, _ok_probe)
    later = datetime.now(timezone.utc) + timedelta(hours=30)
    assert cmid in {i["id"] for i in w.outbound_items(later)}


# ── receiver: carried and labelled ──────────────────────────────────────────

def test_inbox_carries_notice_from_hub_metadata(sc):
    inbox = sc["inbox"]

    def reader(topic, cursor, limit=None):
        if cursor:
            return []
        return [{"offset": 0, "ts": 1, "payload": "fyi",
                 "metadata": {"client_msg_id": "n-1", "conversation_id": "c",
                              "from_agent": "agentB", "notice": "1"}},
                {"offset": 1, "ts": 1, "payload": "q?",
                 "metadata": {"client_msg_id": "c-1", "conversation_id": "c",
                              "from_agent": "agentB"}}]
    got = {m["client_msg_id"]: m for m in inbox.pending(reader=reader, advance=False)}
    assert got["n-1"].get("notice") is True
    assert not got["c-1"].get("notice")


def test_hook_labels_notice_and_leaves_ordinary_message_unchanged(sc):
    hooks = sc["hooks"]
    base = {"client_msg_id": "m-1", "from": "agentB", "conversation_id": "c", "body": "hi"}
    plain = "\n".join(hooks._block(dict(base), "tok", "fw"))
    note = "\n".join(hooks._block(dict(base, notice=True), "tok", "fw"))
    assert "notice — no reply expected" in note
    assert "notice" not in plain and "reply: fw sidecar send" in plain
    # the evidence header the finalizer matches is identical for both
    assert hooks._header(dict(base), "tok") == hooks._header(dict(base, notice=True), "tok")
    assert "notice — no reply expected" in hooks._frame([dict(base, notice=True)], "tok")


def test_receiver_stores_notice_envelope_verbatim(sc):
    r = sc["receiver"]
    ok, err = r.store_message("n-2", {"client_msg_id": "n-2", "from": "agentB",
                                      "body": "fyi", "notice": True})
    assert ok, err
    assert r.read_message("n-2").get("notice") is True
