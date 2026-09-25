"""T-3462 (OBS-529) — the sweep's answered-check must read every topic the
reader drains, not the circuit topic alone.

`pending()` was widened for the T-3433 circuit-addressing transition to drain
`inbox:<circuit>` AND the legacy `sidecar:<agent>` alias. The sweep's
`answered_conversations()` was not. The two lists were written out separately
at each call site, so only one of them moved.

The consequence was not a lost message — `pending()` still surfaced
everything to the agent — it was that the SWEEP could not see a reply. A peer
answering on the legacy rail left the ack-ledger row open, so every five
minutes the retry ladder re-posted, nudged, and finally fired an operator
notice for a conversation answered days earlier. Measured on the live corpus
the day it was found: circuit topic 0 foreign conversations, legacy topic 8,
including all three that had climbed to rung 5, and
`answered_conversations()` returning the empty set.

`answered_conversations` had NO test coverage before this file, which is why
the drift survived the transition that caused it.

No live corpus counts are pinned (T-3326) — every topic here is a fixture.
"""

import importlib

import pytest


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "answered-test")
    import lib.sidecar.outbox as outbox
    import lib.sidecar.inbox as inbox
    import lib.sidecar.retry as retry
    for m in (outbox, inbox, retry):
        importlib.reload(m)
    return inbox, retry


def _env(conversation, from_agent, offset=0):
    """One envelope as the hub returns it."""
    return {"offset": offset,
            "metadata": {"conversation_id": conversation,
                         "from_agent": from_agent,
                         "client_msg_id": f"cmid-{conversation}-{offset}"}}


def _reader_for(by_topic):
    """A reader that serves a fixed envelope list per topic."""
    calls = []

    def reader(topic, cursor, limit=100, **kw):
        calls.append((topic, cursor))
        return list(by_topic.get(topic, []))

    reader.calls = calls
    return reader


# ── the regression ────────────────────────────────────────────────────────

def test_reply_on_the_legacy_rail_is_seen(sc):
    """THE bug. A peer answers on `sidecar:<agent>`; nothing on the circuit."""
    inbox, retry = sc
    me = inbox.agent_id()
    reader = _reader_for({
        inbox.inbox_topic(me): [],
        inbox.legacy_topics(me)[0]: [_env("conv-legacy", "832-Workflow-designer")],
    })
    assert retry.answered_conversations(reader=reader, agent=me) == {"conv-legacy"}


def test_reply_on_the_circuit_rail_is_still_seen(sc):
    """The leg that catches a fix which swaps one blindness for another."""
    inbox, retry = sc
    me = inbox.agent_id()
    reader = _reader_for({
        inbox.inbox_topic(me): [_env("conv-circuit", "010-termlink")],
        inbox.legacy_topics(me)[0]: [],
    })
    assert retry.answered_conversations(reader=reader, agent=me) == {"conv-circuit"}


def test_replies_on_both_rails_union(sc):
    inbox, retry = sc
    me = inbox.agent_id()
    reader = _reader_for({
        inbox.inbox_topic(me): [_env("conv-a", "peer-a")],
        inbox.legacy_topics(me)[0]: [_env("conv-b", "peer-b")],
    })
    assert retry.answered_conversations(reader=reader, agent=me) == {"conv-a", "conv-b"}


def test_every_read_topic_is_actually_consulted(sc):
    """Pins the mechanism, not just the result: both topics are read.

    A future third topic added to `read_topics()` is covered by construction
    rather than needing this file edited — which is precisely what did not
    happen when the circuit topic was introduced.
    """
    inbox, retry = sc
    me = inbox.agent_id()
    reader = _reader_for({})
    retry.answered_conversations(reader=reader, agent=me)
    consulted = [t for t, _cursor in reader.calls]
    assert consulted == inbox.read_topics(me)


# ── it is still a peek ────────────────────────────────────────────────────

def test_reads_from_cursor_zero_on_every_topic(sc):
    """Answered-detection must not depend on where the agent's cursor sits."""
    inbox, retry = sc
    me = inbox.agent_id()
    reader = _reader_for({})
    retry.answered_conversations(reader=reader, agent=me)
    assert {cursor for _t, cursor in reader.calls} == {0}


def test_peek_does_not_advance_any_cursor_or_seen_set(sc):
    """`fw sidecar inbox` owns the cursors. A sweep that consumed messages
    would hide them from the agent — a worse bug than the one being fixed."""
    inbox, retry = sc
    me = inbox.agent_id()
    inbox.save_state({"topics": {inbox.inbox_topic(me): {"cursor": 3}}, "seen": ["keep"]})
    before = inbox.load_state()
    reader = _reader_for({
        inbox.legacy_topics(me)[0]: [_env("conv-legacy", "peer")],
    })
    retry.answered_conversations(reader=reader, agent=me)
    assert inbox.load_state() == before


# ── our own traffic is not an answer ──────────────────────────────────────

def test_our_own_message_does_not_count_as_a_reply(sc):
    """Otherwise every conversation closes the moment we open it."""
    inbox, retry = sc
    me = inbox.agent_id()
    reader = _reader_for({
        inbox.legacy_topics(me)[0]: [_env("conv-mine", me)],
    })
    assert retry.answered_conversations(reader=reader, agent=me) == set()


def test_envelope_without_a_conversation_id_is_ignored(sc):
    inbox, retry = sc
    me = inbox.agent_id()
    reader = _reader_for({
        inbox.legacy_topics(me)[0]: [{"offset": 0, "metadata": {"from_agent": "peer"}}],
    })
    assert retry.answered_conversations(reader=reader, agent=me) == set()


# ── the shared definition ─────────────────────────────────────────────────

def test_pending_and_answered_resolve_the_same_topics(sc):
    """The structural half of the fix: one definition, two callers.

    Two hand-written copies is how this happened. If a future change widens
    one call site instead of `read_topics()`, this goes red.
    """
    inbox, retry = sc
    me = inbox.agent_id()
    pending_reader = _reader_for({})
    inbox.pending(me, reader=pending_reader, advance=False)
    answered_reader = _reader_for({})
    retry.answered_conversations(reader=answered_reader, agent=me)
    assert [t for t, _c in pending_reader.calls] == [t for t, _c in answered_reader.calls]


def test_read_topics_includes_circuit_and_legacy(sc):
    inbox, _retry = sc
    me = inbox.agent_id()
    topics = inbox.read_topics(me)
    assert inbox.inbox_topic(me) in topics
    assert inbox.legacy_topics(me)[0] in topics
