"""T-3442 — arc-011 sidecar: DM rail discovery and draining.

Fixture shape mirrors test_sidecar_inbox.py's `mod` fixture (same
FRAMEWORK_ROOT sandbox / reload dance) since `lib.sidecar.dm` shares
`inbox.py`'s cursor store and reuses `inbox.default_reader`'s contract.
"""

import base64
import importlib

import pytest

OUR_KEY = "d1993c2c3ec44c94"
PEER_KEY = "3bba15e681b3a078"
OTHER_KEY = "6a646ce8b1bc6560"


@pytest.fixture()
def mod(tmp_path, monkeypatch):
    project = tmp_path / "999-Agentic-Engineering-Framework"
    project.mkdir(exist_ok=True)
    monkeypatch.setenv("FRAMEWORK_ROOT", str(project))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_IDENTITY_FP", OUR_KEY)
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)
    import lib.sidecar.outbox as outbox
    import lib.sidecar.inbox as inbox
    import lib.sidecar.dm as dm
    importlib.reload(outbox)
    importlib.reload(inbox)
    importlib.reload(dm)
    return dm


def _topic(count, latest_offset, name):
    return {"name": name, "count": count, "latest_offset": latest_offset}


def _lister(*topics):
    def lister():
        return list(topics)
    return lister


def _env(offset, msg_type="chat", body="hi", sender="peer", ts=1790000000000):
    return {
        "offset": offset,
        "msg_type": msg_type,
        "sender_id": sender,
        "metadata": {},
        "payload_b64": base64.b64encode(body.encode()).decode(),
        "ts": ts + offset,
    }


def _reader_for(envelopes):
    def reader(_topic, cursor, limit=100):
        return [e for e in envelopes if e["offset"] >= cursor][:limit]
    return reader


# ── identity ─────────────────────────────────────────────────────────────

def test_identity_fingerprint_reads_the_env_override(mod):
    assert mod.identity_fingerprint() == OUR_KEY


# ── rails_for_key: only rails where our key is a party ─────────────────────

def test_rails_for_key_matches_either_side(mod):
    rails = [
        _topic(2, 1, f"dm:{PEER_KEY}:{OUR_KEY}"),   # us as second segment
        _topic(2, 1, f"dm:{OUR_KEY}:{PEER_KEY}"),   # us as first segment
        _topic(2, 1, f"dm:{OTHER_KEY}:{PEER_KEY}"),  # neither side is us
        {"name": "agent-chat-arc", "count": 5, "latest_offset": 4},  # not dm:*
    ]
    found = mod.rails_for_key(lister=_lister(*rails))
    names = {r["name"] for r in found}
    assert names == {f"dm:{PEER_KEY}:{OUR_KEY}", f"dm:{OUR_KEY}:{PEER_KEY}"}


def test_a_rail_not_addressed_to_our_key_is_ignored(mod):
    """T-3442 AC4: the third fixture requirement — a rail neither side of
    which is us must not appear in summary, pending, or stale."""
    other_rail = _topic(3, 2, f"dm:{OTHER_KEY}:{PEER_KEY}")
    assert mod.summary(lister=_lister(other_rail)) == []
    assert mod.pending(lister=_lister(other_rail), reader=_reader_for([])) == []
    assert mod.stale(lister=_lister(other_rail), reader=_reader_for([])) == []


def test_malformed_topic_name_is_skipped_not_guessed(mod):
    # three segments after "dm:" — not a clean two-party rail
    weird = {"name": f"dm:{OUR_KEY}:{PEER_KEY}:extra", "count": 1, "latest_offset": 0}
    assert mod.rails_for_key(lister=_lister(weird)) == []


# ── summary(): the AC1 peek shape ───────────────────────────────────────────

def test_summary_reports_unread_against_recorded_cursor(mod):
    """T-3442 AC4 fixture: 3 posts, cursor at 1 -> peek reports 2 unread."""
    rail_name = f"dm:{PEER_KEY}:{OUR_KEY}"
    rail = _topic(3, 2, rail_name)  # offsets 0,1,2 -> latest_offset=2, count=3
    state = {"topics": {rail_name: {"cursor": 1}}}

    rows = mod.summary(lister=_lister(rail), state=state)

    assert len(rows) == 1
    assert rows[0]["topic"] == rail_name
    assert rows[0]["count"] == 3
    assert rows[0]["cursor"] == 1
    assert rows[0]["unread"] == 2


def test_summary_defaults_cursor_to_zero_for_a_never_read_rail(mod):
    rail_name = f"dm:{PEER_KEY}:{OUR_KEY}"
    rail = _topic(3, 2, rail_name)
    rows = mod.summary(lister=_lister(rail), state={"topics": {}})
    assert rows[0]["cursor"] == 0
    assert rows[0]["unread"] == 3


def test_summary_does_not_move_any_cursor(mod):
    rail_name = f"dm:{PEER_KEY}:{OUR_KEY}"
    rail = _topic(3, 2, rail_name)
    mod.summary(lister=_lister(rail))
    # nothing was written — the on-disk state is untouched
    assert mod.inbox.load_state().get("topics", {}) == {}


def test_unread_is_bounded_by_retention_truncated_count(mod):
    """latest_offset can run far ahead of count when old offsets were
    evicted by retention; unread must never claim more than what remains."""
    rail_name = f"dm:{PEER_KEY}:{OUR_KEY}"
    rail = _topic(5, 200, rail_name)  # only 5 posts survive, offset runs to 200
    rows = mod.summary(lister=_lister(rail), state={"topics": {}})
    assert rows[0]["unread"] == 5


# ── pending(): drains content, advances the SAME cursor store ──────────────

def test_pending_drains_content_and_skips_meta_envelopes(mod):
    rail_name = f"dm:{PEER_KEY}:{OUR_KEY}"
    rail = _topic(3, 2, rail_name)
    envelopes = [
        _env(0, msg_type="topic_metadata", body="created by termlink"),
        _env(1, msg_type="chat", body="hello"),
        _env(2, msg_type="reaction", body=""),
    ]
    msgs = mod.pending(lister=_lister(rail), reader=_reader_for(envelopes))

    assert [m["body"] for m in msgs] == ["hello"]
    assert msgs[0]["topic"] == rail_name
    assert msgs[0]["from"] == "peer"


def test_pending_advances_cursor_past_meta_and_content_alike(mod):
    """T-3442 AC4: cursor advance after a non-peek read -> 0 unread."""
    rail_name = f"dm:{PEER_KEY}:{OUR_KEY}"
    envelopes = [
        _env(0, msg_type="topic_metadata"),
        _env(1, msg_type="chat", body="hello"),
        _env(2, msg_type="chat", body="world"),
    ]
    rail = lambda: [_topic(3, 2, rail_name)]  # noqa: E731 — cheap stand-in lister
    reader = _reader_for(envelopes)

    first = mod.pending(lister=rail, reader=reader)
    assert len(first) == 2  # two chat posts, meta excluded

    state = mod.inbox.load_state()
    assert state["topics"][rail_name]["cursor"] == 3

    # A fresh summary() against the advanced cursor reports zero unread.
    rows = mod.summary(lister=rail)
    assert rows[0]["unread"] == 0

    second = mod.pending(lister=rail, reader=reader)
    assert second == []


def test_pending_peek_style_does_not_advance(mod):
    rail_name = f"dm:{PEER_KEY}:{OUR_KEY}"
    rail = _topic(1, 0, rail_name)
    envelopes = [_env(0, body="hello")]

    assert len(mod.pending(lister=_lister(rail), reader=_reader_for(envelopes),
                            advance=False)) == 1
    # still unread — advance=False never wrote a cursor
    assert len(mod.pending(lister=_lister(rail), reader=_reader_for(envelopes),
                            advance=False)) == 1


def test_pending_cursor_lives_in_the_shared_topics_map(mod):
    """T-3442 AC1: the rail's cursor sits alongside inbox:/sidecar: topic
    cursors in the SAME state file, not a second store."""
    rail_name = f"dm:{PEER_KEY}:{OUR_KEY}"
    rail = _topic(1, 0, rail_name)
    mod.inbox.save_state({"topics": {mod.inbox.inbox_topic(): {"cursor": 4}}})

    mod.pending(lister=_lister(rail), reader=_reader_for([_env(0)]))

    state = mod.inbox.load_state()
    assert state["topics"][mod.inbox.inbox_topic()]["cursor"] == 4  # untouched
    assert state["topics"][rail_name]["cursor"] == 1                # added alongside


# ── stale(): the doctor/audit WARN fact source ──────────────────────────────

def test_stale_reports_rails_past_the_age_threshold(mod):
    import datetime

    rail_name = f"dm:{PEER_KEY}:{OUR_KEY}"
    rail = _topic(1, 0, rail_name)
    old_ts_ms = 1_700_000_000_000  # long ago
    envelopes = [_env(0, msg_type="chat", body="old", ts=old_ts_ms - 0)]
    envelopes[0]["ts"] = old_ts_ms
    now = datetime.datetime(2026, 9, 24, tzinfo=datetime.timezone.utc)

    rows = mod.stale(min_age_hours=24, lister=_lister(rail),
                      reader=_reader_for(envelopes), now=now)

    assert len(rows) == 1
    assert rows[0]["topic"] == rail_name
    assert rows[0]["unread"] == 1
    assert rows[0]["age_hours"] > 24


def test_stale_is_silent_when_unread_is_recent(mod):
    import datetime

    rail_name = f"dm:{PEER_KEY}:{OUR_KEY}"
    rail = _topic(1, 0, rail_name)
    now = datetime.datetime(2026, 9, 24, tzinfo=datetime.timezone.utc)
    recent_ms = int((now - datetime.timedelta(hours=1)).timestamp() * 1000)
    envelopes = [_env(0, msg_type="chat", body="fresh", ts=recent_ms)]

    rows = mod.stale(min_age_hours=24, lister=_lister(rail),
                      reader=_reader_for(envelopes), now=now)
    assert rows == []


def test_stale_is_silent_when_nothing_is_unread(mod):
    rail_name = f"dm:{PEER_KEY}:{OUR_KEY}"
    rail = _topic(1, 0, rail_name)  # 1 post, offset 0
    mod.inbox.save_state({"topics": {rail_name: {"cursor": 1}}})  # fully read

    rows = mod.stale(min_age_hours=24, lister=_lister(rail), reader=_reader_for([]))
    assert rows == []
