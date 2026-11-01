"""T-4963 — a reply that arrives over the DIRECT route settles a hub consult.

055-agentic-fleet-cockpit (msgs de1569c0, d3a169a5): consult 2ad78ca1 was answered on its
own conversation by a peer other than the one addressed, over 055's direct receiver, and
the retry ladder kept escalating it for days because `reply_signals` read only the hub
inbox. The receiver's stored messages now count too. A reply on a DIFFERENT conversation
is not guessed at (the sender's `fw sidecar settle-sent` covers that).
All state lives in a temp PROJECT_ROOT; the live sidecar is never touched (T-4315).
"""

import importlib
import json
from datetime import datetime, timedelta, timezone

import pytest

T0 = datetime(2026, 11, 1, 12, 0, 0, tzinfo=timezone.utc)


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    (tmp_path / ".context").mkdir()
    (tmp_path / ".framework.yaml").write_text("project_name: direct-a\n")
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "direct-a")
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    for k in ("NTFY_ENABLED", "FW_SIDECAR_NOTIFY_CMD"):
        monkeypatch.delenv(k, raising=False)
    from lib.sidecar import delivery, inbox, outbox, receipts, receiver, retry
    for m in (outbox, delivery, inbox, receipts, receiver, retry):
        importlib.reload(m)
    return {"outbox": outbox, "delivery": delivery, "retry": retry, "root": tmp_path}


def _ok_probe(_hub):
    from lib.sidecar import delivery
    return delivery.ProbeResult(True)


def _empty_reader(_topic, _cursor, _limit=None):
    return []


def _consult(sc, conversation):
    cmid = sc["outbox"].write_message(from_id="direct-a", to="termlink", body="question",
                                      conversation_id=conversation)
    sc["delivery"].deliver(cmid, lambda _m: None, _ok_probe, now=T0)   # posted, unread
    return cmid


def _direct_in(sc, msg_id, **env):
    d = sc["root"] / ".context" / "sidecar" / "receiver" / "messages"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{msg_id}.json").write_text(json.dumps(dict({"client_msg_id": msg_id, "body": "x",
                                                       "urgent": False}, **env)))


def _sweep(sc):
    acted = []
    report = sc["retry"].sweep(now=T0 + timedelta(days=2), transport=acted.append,
                               probe=_ok_probe, reader=_empty_reader,
                               nudge=lambda msg, *a, **k: acted.append(msg) or "x",
                               operator_notice=lambda msg, *a, **k: acted.append(msg) or "x")
    return report, {m["client_msg_id"] for m in acted}


def test_direct_reply_on_the_conversation_from_another_identity_settles(sc):
    ob, retry = sc["outbox"], sc["retry"]
    answered = _consult(sc, "worker-lifecycle-2026-10-21")
    other = _consult(sc, "unrelated-conv")
    _direct_in(sc, "6f6e1627", **{"from": "010-termlink",
                                  "conversation_id": "worker-lifecycle-2026-10-21"})
    report, touched = _sweep(sc)
    row = ob.latest_ack_state(answered)
    assert not retry.is_open(row) and row["error"].startswith(retry.ANSWERED)
    assert answered not in touched
    assert retry.is_open(ob.latest_ack_state(other)) and other in touched   # still chased


def test_direct_in_reply_to_settles_by_id_even_on_another_conversation(sc):
    ob, retry = sc["outbox"], sc["retry"]
    cmid = _consult(sc, "consult-x")
    _direct_in(sc, "r1", **{"from": "peer-b", "conversation_id": "elsewhere",
                            "in_reply_to": cmid})
    _sweep(sc)
    assert not retry.is_open(ob.latest_ack_state(cmid))


def test_own_messages_receipts_and_bad_files_do_not_settle(sc):
    ob, retry = sc["outbox"], sc["retry"]
    cmid = _consult(sc, "consult-y")
    _direct_in(sc, "own", **{"from": "direct-a", "conversation_id": "consult-y"})
    _direct_in(sc, "rcpt", **{"from": "peer-b", "conversation_id": "consult-y",
                              "kind": "receipt"})
    d = sc["root"] / ".context" / "sidecar" / "receiver" / "messages"
    (d / "torn.json").write_text("{not json")
    _sweep(sc)
    assert retry.is_open(ob.latest_ack_state(cmid))
