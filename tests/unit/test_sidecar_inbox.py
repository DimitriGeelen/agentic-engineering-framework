"""T-3406 — arc-011 sidecar inbox: cursor, dedupe, identity (slice 4).

T-3433 extends it: the drain covers both the `inbox:<circuit-id>` topic and
the legacy `sidecar:` alias, with a cursor per topic and one shared seen-set.
"""

HUB = "cacc73ea32b121dd"
PROJ = "999-Agentic-Engineering-Framework"

import base64
import importlib

import pytest


@pytest.fixture()
def mod(tmp_path, monkeypatch):
    project = tmp_path / "999-Agentic-Engineering-Framework"
    project.mkdir(exist_ok=True)
    monkeypatch.setenv("FRAMEWORK_ROOT", str(project))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_HOST", "host107.ring20.lan")
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)
    monkeypatch.delenv("FW_FOCUS_SESSION_KEY", raising=False)
    monkeypatch.delenv("TERMLINK_SESSION", raising=False)
    import lib.sidecar.outbox as outbox
    import lib.sidecar.circuit as circuit
    import lib.sidecar.inbox as inbox
    importlib.reload(outbox)
    importlib.reload(circuit)
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


def _reader_for(envelopes, *, only=None):
    """Reader that honours the cursor, like the real `channel subscribe`.

    `only` scopes the envelopes to one topic; without it every topic the
    drain visits answers with the same list (which is what the pre-T-3433
    single-topic tests assumed, and what the shared seen-set must survive).
    """
    def reader(topic, cursor, limit=100):
        if only is not None and topic != only:
            return []
        return [e for e in envelopes if e["offset"] >= cursor]
    return reader


def test_agent_id_defaults_to_project_dir_and_is_overridable(mod, tmp_path, monkeypatch):
    assert mod.agent_id() == PROJ
    # No distinct agent: our inbox IS the durable role address (T-3433).
    assert mod.inbox_topic() == f"inbox:{HUB}/{PROJ}"
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "responder-7")
    assert mod.agent_id() == "responder-7"
    assert mod.inbox_topic() == f"inbox:{HUB}/{PROJ}/responder-7"
    assert mod.inbox_topic("other") == f"inbox:{HUB}/{PROJ}/other"
    assert mod.inbox_topic("010-termlink") == f"inbox:{HUB}/010-termlink"


def test_legacy_sidecar_topic_is_a_read_alias(mod, monkeypatch):
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "responder-7")
    assert mod.legacy_topics() == ["sidecar:responder-7"]
    assert mod.legacy_topics("other") == ["sidecar:other"]


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
    """No id means no dedupe key — show it rather than silently dropping.

    Scoped to one topic: without a key the dual drain (T-3433) cannot collapse
    the same envelope seen on both, and surfacing it twice is the honest
    outcome. Every sender we ship stamps the id.
    """
    envelopes = [_env(0, body="a"), _env(1, body="b")]
    reader = _reader_for(envelopes, only=mod.inbox_topic())

    msgs = mod.pending(reader=reader)
    assert [m["body"] for m in msgs] == ["a", "b"]
    assert all(m["client_msg_id"] is None for m in msgs)


def test_seen_set_is_bounded(mod, monkeypatch):
    monkeypatch.setattr(mod, "SEEN_CAP", 3)
    envelopes = [_env(i, client_msg_id=f"m{i}") for i in range(10)]
    mod.pending(reader=_reader_for(envelopes))

    state = mod.load_state()
    assert len(state["seen"]) == 3      # shared across topics since T-3433
    assert state["seen"] == ["m7", "m8", "m9"]  # keeps the most recent
    assert state["topics"][mod.inbox_topic()]["cursor"] == 10


def test_state_survives_a_reload(mod):
    reader = _reader_for([_env(0, client_msg_id="m1")])
    mod.pending(reader=reader)

    importlib.reload(mod)
    assert mod.pending(reader=reader) == []  # cursor read back from disk


# ── T-3433: dual drain over the transition ──────────────────────────────────

def test_a_consult_on_each_topic_both_surface_once(mod, monkeypatch):
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "responder-7")
    new_topic = mod.inbox_topic()
    legacy = mod.legacy_topics()[0]
    per_topic = {
        new_topic: [_env(0, body="on the new topic", client_msg_id="m-new")],
        legacy: [_env(0, body="on the legacy alias", client_msg_id="m-old")],
    }

    def reader(topic, cursor, limit=100):
        return [e for e in per_topic.get(topic, []) if e["offset"] >= cursor]

    msgs = mod.pending(reader=reader)
    assert sorted(m["client_msg_id"] for m in msgs) == ["m-new", "m-old"]
    assert {m["topic"] for m in msgs} == {new_topic, legacy}
    assert mod.pending(reader=reader) == []          # each shown exactly once


def test_the_same_message_on_both_topics_surfaces_once(mod, monkeypatch):
    """A peer mid-transition that posts to both must not double-deliver."""
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "responder-7")
    dual = [_env(0, body="dual-posted", client_msg_id="m-dual")]
    msgs = mod.pending(reader=_reader_for(dual))
    assert len(msgs) == 1


def test_cursors_are_kept_per_topic(mod, monkeypatch):
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "responder-7")
    new_topic = mod.inbox_topic()
    legacy = mod.legacy_topics()[0]
    per_topic = {new_topic: [_env(0, client_msg_id="a"), _env(1, client_msg_id="b")],
                 legacy: [_env(0, client_msg_id="c")]}

    def reader(topic, cursor, limit=100):
        return [e for e in per_topic.get(topic, []) if e["offset"] >= cursor]

    mod.pending(reader=reader)
    topics = mod.load_state()["topics"]
    assert topics[new_topic]["cursor"] == 2
    assert topics[legacy]["cursor"] == 1


def test_pre_t3433_per_topic_seen_sets_are_honoured(mod, monkeypatch):
    """Upgrading must not re-surface a consult already shown under the old
    state shape (per-topic `seen`), so the shared set is seeded from it."""
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "responder-7")
    legacy = mod.legacy_topics()[0]
    mod.save_state({"topics": {legacy: {"cursor": 0, "seen": ["m-old"]}}})
    msgs = mod.pending(reader=_reader_for([_env(0, client_msg_id="m-old")]))
    assert msgs == []


def test_pending_surfaces_the_senders_circuit(mod, monkeypatch):
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "responder-7")
    env = _env(0, client_msg_id="m1")
    env["metadata"]["from_circuit"] = f"//other.host/{HUB}/010-termlink/worker-3"
    msgs = mod.pending(reader=_reader_for([env]))
    assert msgs[0]["from_circuit"] == f"//other.host/{HUB}/010-termlink/worker-3"
    assert msgs[0]["from"] == "peerA"        # compatibility field still mapped


def test_peek_advances_neither_cursor(mod, monkeypatch):
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "responder-7")
    reader = _reader_for([_env(0, client_msg_id="m1")])
    assert len(mod.pending(reader=reader, advance=False)) == 1
    assert len(mod.pending(reader=reader, advance=False)) == 1
