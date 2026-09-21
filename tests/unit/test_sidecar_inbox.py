"""T-3406 — arc-011 sidecar inbox: cursor, dedupe, identity (slice 4)."""

import base64
import importlib

import pytest


@pytest.fixture()
def mod(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)
    import lib.sidecar.outbox as outbox
    import lib.sidecar.inbox as inbox
    importlib.reload(outbox)
    importlib.reload(inbox)
    return inbox


def _env(offset, body="hi", client_msg_id=None, sender="peerA", conv="c1"):
    meta = {"from_agent": sender, "conversation_id": conv}
    if client_msg_id:
        meta["client_msg_id"] = client_msg_id
    return {
        "offset": offset,
        "metadata": meta,
        "payload_b64": base64.b64encode(body.encode()).decode(),
        "ts": 1790000000000 + offset,
    }


def _reader_for(envelopes):
    """Reader that honours the cursor, like the real `channel subscribe`."""
    def reader(topic, cursor, limit=100):
        return [e for e in envelopes if e["offset"] >= cursor]
    return reader


def test_agent_id_defaults_to_project_dir_and_is_overridable(mod, tmp_path, monkeypatch):
    assert mod.agent_id() == tmp_path.name
    assert mod.inbox_topic() == f"sidecar:{tmp_path.name}"
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "responder-7")
    assert mod.agent_id() == "responder-7"
    assert mod.inbox_topic() == "sidecar:responder-7"
    assert mod.inbox_topic("other") == "sidecar:other"


def test_pending_decodes_and_maps_envelope_fields(mod):
    reader = _reader_for([_env(0, body="what is the risk?", client_msg_id="m1")])
    msgs = mod.pending(reader=reader)

    assert len(msgs) == 1
    assert msgs[0]["body"] == "what is the risk?"
    assert msgs[0]["from"] == "peerA"
    assert msgs[0]["conversation_id"] == "c1"
    assert msgs[0]["offset"] == 0


def test_cursor_advances_so_a_message_is_shown_once(mod):
    envelopes = [_env(0, client_msg_id="m1"), _env(1, client_msg_id="m2")]
    reader = _reader_for(envelopes)

    first = mod.pending(reader=reader)
    assert [m["offset"] for m in first] == [0, 1]

    second = mod.pending(reader=reader)
    assert second == []  # cursor moved past both

    envelopes.append(_env(2, body="later", client_msg_id="m3"))
    third = mod.pending(reader=reader)
    assert [m["offset"] for m in third] == [2]


def test_peek_does_not_advance_the_cursor(mod):
    reader = _reader_for([_env(0, client_msg_id="m1")])

    assert len(mod.pending(reader=reader, advance=False)) == 1
    assert len(mod.pending(reader=reader, advance=False)) == 1  # still there
    assert len(mod.pending(reader=reader)) == 1  # this one consumes it
    assert mod.pending(reader=reader) == []


def test_duplicate_past_the_hub_ttl_is_shown_once(mod):
    """The OBS-447 case: same client_msg_id re-appended at a later offset.

    Measured in T-3405 — the hub's own dedupe lapses after ~5 minutes, so a
    sender retrying on a longer deadline appends a genuine duplicate. Only
    the receiver can collapse it, which is what this asserts.
    """
    envelopes = [_env(0, body="original", client_msg_id="same-id")]
    reader = _reader_for(envelopes)

    first = mod.pending(reader=reader)
    assert len(first) == 1

    # Sender retried after the TTL lapsed: identical id, new offset.
    envelopes.append(_env(1, body="original", client_msg_id="same-id"))
    second = mod.pending(reader=reader)

    assert second == []  # suppressed on client_msg_id, not on offset


def test_envelope_without_client_msg_id_is_not_suppressed(mod):
    """No id means no dedupe key — show it rather than silently dropping."""
    envelopes = [_env(0, body="a"), _env(1, body="b")]
    reader = _reader_for(envelopes)

    msgs = mod.pending(reader=reader)
    assert [m["body"] for m in msgs] == ["a", "b"]
    assert all(m["client_msg_id"] is None for m in msgs)


def test_seen_set_is_bounded(mod, monkeypatch):
    monkeypatch.setattr(mod, "SEEN_CAP", 3)
    envelopes = [_env(i, client_msg_id=f"m{i}") for i in range(10)]
    mod.pending(reader=_reader_for(envelopes))

    state = mod.load_state()
    entry = state["topics"][mod.inbox_topic()]
    assert len(entry["seen"]) == 3
    assert entry["seen"] == ["m7", "m8", "m9"]  # keeps the most recent
    assert entry["cursor"] == 10


def test_state_survives_a_reload(mod):
    reader = _reader_for([_env(0, client_msg_id="m1")])
    mod.pending(reader=reader)

    importlib.reload(mod)
    assert mod.pending(reader=reader) == []  # cursor read back from disk
