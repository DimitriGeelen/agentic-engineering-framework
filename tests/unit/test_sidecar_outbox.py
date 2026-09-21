"""T-3402 — arc-011 sidecar outbox substrate (T-3397 Amendment 5, slice 1)."""

import importlib
import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest


@pytest.fixture()
def outbox(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    import lib.sidecar.outbox as mod
    importlib.reload(mod)
    return mod


def test_write_message_creates_message_before_flag(outbox):
    client_msg_id = outbox.write_message(
        from_id="agentA", to="agentB", body="hello",
        conversation_id="conv-1",
    )
    outbox_dir = outbox._outbox_dir()
    msg_path = outbox_dir / f"{client_msg_id}.json"
    flag_path = outbox_dir / f"{client_msg_id}.flag"

    assert msg_path.exists()
    assert flag_path.exists()
    with open(msg_path, encoding="utf-8") as fh:
        data = json.load(fh)
    assert data["from"] == "agentA"
    assert data["to"] == "agentB"
    assert data["body"] == "hello"
    assert data["conversation_id"] == "conv-1"
    assert data["hub"] is None


def test_list_pending_excludes_message_with_no_flag(outbox):
    real_id = outbox.write_message(
        from_id="a", to="b", body="x", conversation_id="c1",
    )
    outbox_dir = outbox._outbox_dir()
    # Simulate a torn write: message file present, flag absent.
    torn_id = "torn-write-no-flag"
    with open(outbox_dir / f"{torn_id}.json", "w", encoding="utf-8") as fh:
        json.dump({"client_msg_id": torn_id}, fh)

    pending = outbox.list_pending()
    assert real_id in pending
    assert torn_id not in pending


def test_ack_ledger_round_trip_returns_latest_state(outbox):
    client_msg_id = "cmid-1"
    outbox.record_ack(client_msg_id, target="agentB", hub=None, state=outbox.STORED,
                       deadline=(datetime.now(timezone.utc) + timedelta(seconds=30)).isoformat())
    outbox.record_ack(client_msg_id, target="agentB", hub=None, state=outbox.INJECTED_NOW)

    latest = outbox.latest_ack_state(client_msg_id)
    assert latest is not None
    assert latest["state"] == outbox.INJECTED_NOW  # last-written, not first


def test_resolve_expired_flips_past_deadline_stored_row(outbox):
    expired_id = "cmid-expired"
    past_deadline = (datetime.now(timezone.utc) - timedelta(seconds=5)).isoformat()
    outbox.record_ack(expired_id, target="agentB", hub=None, state=outbox.STORED,
                       deadline=past_deadline)

    terminal_id = "cmid-already-terminal"
    outbox.record_ack(terminal_id, target="agentB", hub=None, state=outbox.STORED,
                       deadline=past_deadline)
    outbox.record_ack(terminal_id, target="agentB", hub=None, state=outbox.INJECTED_LATER)

    flipped = outbox.resolve_expired()

    assert expired_id in flipped
    assert terminal_id not in flipped  # already terminal — left untouched

    assert outbox.latest_ack_state(expired_id)["state"] == outbox.UNKNOWN
    assert outbox.latest_ack_state(terminal_id)["state"] == outbox.INJECTED_LATER
