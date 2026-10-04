"""T-3804 — a reply settles the consult; nudges stop.

832-Workflow-designer nudged 999 about consults cf10f23e, e28a469a, cc12f703
and 9bcc403a 5-10 times AFTER 999 had replied with --in-reply-to <base id>.
Three independent gaps, each pinned here:

1. The sweep's reply walk read one page (cursor 0, limit 100). 832's inbox
   topic held 493 records and every one of 999's replies on that conversation
   sat at offset 144 or later — invisible.
2. The REPLIED receipt did reach the sender (receipts.jsonl) but the sweep
   never read that ledger.
3. A receipt naming a nudge id (`<base>-nudge-N`) was dropped: no outbox file
   has that name.

Plus the replier side: a hub-path reply carries the id it answers.
"""

import importlib
import json
from datetime import datetime, timedelta, timezone

import pytest

T0 = datetime(2026, 10, 4, 1, 0, 0, tzinfo=timezone.utc)
ME = "832-Workflow-designer"
PEER = "999-Agentic-Engineering-Framework"


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", ME)
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_HOST", "host107.ring20.lan")
    for var in ("TERMLINK_SESSION", "FW_FOCUS_SESSION_KEY"):
        monkeypatch.delenv(var, raising=False)
    import lib.sidecar.outbox as outbox
    import lib.sidecar.delivery as delivery
    import lib.sidecar.inbox as inbox
    import lib.sidecar.receipts as receipts
    import lib.sidecar.retry as retry
    for m in (outbox, delivery, inbox, receipts, retry):
        importlib.reload(m)
    return outbox, delivery, receipts, retry


def _ok_probe(_hub):
    import lib.sidecar.delivery as delivery
    return delivery.ProbeResult(True)


def _empty_reader(_topic, _cursor, _limit=None):
    return []


def _due_nudge_row(outbox, delivery, conversation="sidecar-vendored-consumer-rca"):
    """A delivered consult to PEER whose next rung (a nudge) is due at T0+15m."""
    cmid = outbox.write_message(from_id=ME, to=PEER, body="the question",
                                conversation_id=conversation)
    delivery.deliver(cmid, lambda _m: None, _ok_probe, now=T0)
    outbox.record_ack(cmid, PEER, None, outbox.INJECTED_NOW, attempts=4, rung=2,
                      next_retry_at=(T0 + timedelta(minutes=15)).isoformat())
    return cmid


def _paged_reader(envelopes):
    """Honours cursor/limit like `channel subscribe` does."""
    calls = []

    def reader(topic, cursor, limit=100, **kw):
        calls.append((topic, cursor))
        return [e for e in envelopes if e["offset"] >= cursor][:limit]
    reader.calls = calls
    return reader


def _filler(n, start=0):
    return [{"offset": i, "metadata": {"conversation_id": f"other-{i}", "from_agent": ME,
                                       "client_msg_id": f"own-{i}"}} for i in range(start, start + n)]


# ── gap 1: the walk pages to the end ─────────────────────────────────────────

def test_reply_past_the_first_page_is_seen(sc):
    _outbox, _delivery, _receipts, retry = sc
    reply = {"offset": 144, "metadata": {"conversation_id": "conv-x", "from_agent": PEER,
                                         "client_msg_id": "r1"}}
    reader = _paged_reader(_filler(144) + [reply] + _filler(348, start=145))
    answered, _ = retry.reply_signals(reader=reader)
    assert "conv-x" in answered
    assert any(c > 0 for _t, c in reader.calls), "must page past cursor 0"


def test_sweep_settles_a_consult_answered_at_offset_144(sc):
    outbox, delivery, _receipts, retry = sc
    cmid = _due_nudge_row(outbox, delivery)
    reply = {"offset": 144, "metadata": {"conversation_id": "sidecar-vendored-consumer-rca",
                                         "from_agent": PEER, "client_msg_id": "r1"}}
    posted = []
    report = retry.sweep(now=T0 + timedelta(minutes=15), transport=posted.append,
                         probe=_ok_probe, reader=_paged_reader(_filler(144) + [reply]))
    assert report["nudged"] == 0 and posted == []
    assert outbox.latest_ack_state(cmid)["error"].startswith("answered")


def test_receipts_on_the_topic_are_not_replies(sc):
    _o, _d, _r, retry = sc
    rcpt = {"offset": 0, "metadata": {"kind": "receipt", "conversation_id": "conv-r",
                                      "from_agent": PEER, "receipt_for": "x"}}
    answered, replied = retry.reply_signals(reader=_paged_reader([rcpt]))
    assert answered == set() and replied == set()


# ── gap 2: a REPLIED receipt settles the ladder ──────────────────────────────

def test_replied_receipt_settles_even_before_the_rung_is_due(sc):
    outbox, delivery, receipts, retry = sc
    cmid = _due_nudge_row(outbox, delivery, conversation="conv-not-on-topic")
    assert receipts.record_from_peer(cmid, receipts.REPLIED, PEER, via="hub:test")
    posted = []
    report = retry.sweep(now=T0 + timedelta(minutes=1), transport=posted.append,
                         probe=_ok_probe, reader=_empty_reader)
    assert report["answered"] == 1 and posted == []
    row = outbox.latest_ack_state(cmid)
    assert row["error"].startswith("answered") and row["next_retry_at"] is None
    assert not retry.is_open(row)


def test_without_any_reply_the_nudge_still_fires(sc):
    """Control: the settle paths above are what stop the nudge, not a broken sweep."""
    outbox, delivery, _r, retry = sc
    _due_nudge_row(outbox, delivery, conversation="conv-unanswered")
    posted = []
    report = retry.sweep(now=T0 + timedelta(minutes=15), transport=posted.append,
                         probe=_ok_probe, reader=_empty_reader)
    assert report["nudged"] == 1 and len(posted) == 1


def test_replied_receipt_from_a_non_addressee_is_not_recorded(sc):
    outbox, delivery, receipts, _retry = sc
    cmid = _due_nudge_row(outbox, delivery)
    assert not receipts.record_from_peer(cmid, receipts.REPLIED, "someone-else", via="hub:test")
    assert cmid not in receipts.replied_ids()


# ── gap 3: nudge ids resolve to their base ───────────────────────────────────

def test_base_id_strips_only_the_nudge_suffix(sc):
    _o, _d, receipts, _r = sc
    base = "cc12f703-5ba2-4bfd-95b8-046d5a9dfe00"
    assert receipts.base_id(f"{base}-nudge-9") == base
    assert receipts.base_id(base) == base
    assert receipts.base_id("abc-nudge-x") == "abc-nudge-x"


def test_receipt_for_a_nudge_id_settles_the_base_consult(sc):
    outbox, delivery, receipts, retry = sc
    cmid = _due_nudge_row(outbox, delivery)
    assert receipts.record_from_peer(f"{cmid}-nudge-7", receipts.REPLIED, PEER, via="direct")
    assert cmid in receipts.replied_ids()
    report = retry.sweep(now=T0 + timedelta(minutes=15), transport=lambda m: None,
                         probe=_ok_probe, reader=_empty_reader)
    assert report["answered"] == 1 and report["nudged"] == 0


def test_reply_naming_a_nudge_id_on_the_topic_settles_by_id(sc):
    outbox, delivery, _r, retry = sc
    cmid = _due_nudge_row(outbox, delivery, conversation="conv-a")
    reply = {"offset": 3, "metadata": {"conversation_id": "a-different-conv", "from_agent": PEER,
                                       "client_msg_id": "r9",
                                       "in_reply_to_msg_id": f"{cmid}-nudge-5"}}
    report = retry.sweep(now=T0 + timedelta(minutes=15), transport=lambda m: None,
                         probe=_ok_probe, reader=_paged_reader([reply]))
    assert report["answered"] == 1 and report["nudged"] == 0


# ── replier side: the hub post carries the id it answers ─────────────────────

def test_hub_reply_carries_in_reply_to_msg_id_not_termlinks_offset_key(sc):
    outbox, _d, _r, _retry = sc
    import lib.sidecar.termlink_transport as tt
    importlib.reload(tt)
    cmid = outbox.write_message(from_id=PEER, to=ME, body="answer", conversation_id="c",
                                in_reply_to="base-1")
    msg = json.loads((outbox._outbox_dir() / f"{cmid}.json").read_text())
    argv = tt.build_post_command(msg, binary="termlink")
    assert "in_reply_to_msg_id=base-1" in argv
    assert not any(a.startswith("in_reply_to=") for a in argv)
    assert argv[-2] == "--payload"


def test_replied_receipt_from_cli_names_the_base_id(sc, monkeypatch):
    _o, _d, receipts, _r = sc
    import lib.sidecar_cli as cli
    importlib.reload(cli)
    sent = []
    monkeypatch.setattr(cli.receipts, "origin",
                        lambda cid: {"client_msg_id": cid, "from": ME, "from_circuit": None,
                                     "conversation_id": "c"} if cid.endswith("-nudge-3") else None)
    monkeypatch.setattr(cli.receipts, "send",
                        lambda env, state, by: sent.append((env["client_msg_id"], state)))

    class A:
        in_reply_to = "base-uuid-nudge-3"
    cli._replied_receipt(A())
    assert sent == [("base-uuid", receipts.REPLIED)]
