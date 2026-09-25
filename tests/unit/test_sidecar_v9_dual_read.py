"""T-3479 (arc-011/arc-020 convergence, slice A) — dual-read the V9 address.

Operator ruled T-3475 GO: converge the sidecar onto arc-020's five-part V9
address. This slice is the READ half only — nothing a peer can observe changes
until the write-side cut, which is gated on notifying 832, 010-termlink and
1409-sprind.

The finding that made this cheap: T-3433's Decisions say "Rejected: host-first
5-segment addresses", which reads as a rejection of V9. It is not. It rejects
one SERIALIZATION. `AEFAddress` documents every field as optional — "sparse
addresses are legal" — so a hub-anchored V9 address carries exactly what the
T-3433 circuit form carries and asserts no host. The grammars were never
semantically in conflict; fifteen days apart, neither task noticed.

No live corpus counts are pinned (T-3326) — every address here is constructed.
"""

import importlib

import pytest


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "v9-test")
    import lib.sidecar.outbox as outbox
    import lib.sidecar.circuit as circuit
    import lib.sidecar.inbox as inbox
    import lib.sidecar.retry as retry
    for m in (outbox, circuit, inbox, retry):
        importlib.reload(m)
    return circuit, inbox, retry


# ── the serialization itself ────────────────────────────────────────────────

def test_v9_address_is_the_same_identity_in_the_other_grammar(sc):
    circuit, _, _ = sc
    cid = "HUB1/proj-x/sess-9/agent-a"
    assert circuit.v9_address(cid) == (
        "aef::hub=HUB1::project=proj-x::session=sess-9::@agent-a::")


def test_v9_address_never_emits_a_host(sc):
    """The property that reconciles T-3433 with arc-020.

    A host-qualified circuit id drops its host here for the same reason
    `topic_for_circuit` does: a topic is an object on a hub. If `host=` ever
    appears, the convergence has re-adopted the serialization T-3433 rejected.
    """
    circuit, _, _ = sc
    for cid in ("HUB1/proj-x", "HUB1/proj-x/agent-a",
                "//host7.lan/HUB1/proj-x/agent-a"):
        assert "host=" not in circuit.v9_address(cid)


def test_v9_omits_absent_levels_rather_than_emitting_empties(sc):
    circuit, _, _ = sc
    assert circuit.v9_address("HUB1/proj-x") == "aef::hub=HUB1::project=proj-x::"


def test_v9_topic_carries_the_inbox_prefix(sc):
    """`inbox:*` is what the hub treats as MAIL — wake events, receipts,
    --await-ack (T-3433). A V9 topic that lost the prefix would be a bare
    append log and would silently stop waking anyone."""
    circuit, _, _ = sc
    assert circuit.v9_topic_for_circuit("HUB1/proj-x").startswith("inbox:aef::")


# ── the widening ────────────────────────────────────────────────────────────

def test_read_topics_carries_all_three_forms(sc):
    circuit, inbox, _ = sc
    topics = inbox.read_topics()
    assert len(topics) == len(set(topics)), "duplicate topic in the read set"
    assert any(t.startswith("inbox:aef::") for t in topics), "V9 missing"
    assert any(t.startswith("sidecar:") for t in topics), "legacy alias missing"
    assert any(t.startswith("inbox:") and "aef::" not in t for t in topics), \
        "T-3433 circuit topic missing"


def test_both_readers_follow_without_being_edited(sc):
    """The property T-3462 built `read_topics()` to have, now collected.

    `pending()` and `retry.answered_conversations()` must see the widening
    because they call the shared definition — not because someone remembered
    to edit two call sites. That memory is what failed in OBS-529.
    """
    _, inbox, retry = sc
    import inspect
    for fn in (inbox.pending, retry.answered_conversations):
        assert "read_topics" in inspect.getsource(fn), (
            f"{fn.__qualname__} does not call read_topics — it will drift")


def test_peer_addresses_widen_too(sc):
    _, inbox, _ = sc
    topics = inbox.read_topics("010-termlink")
    assert any("aef::" in t and "010-termlink" in t for t in topics)
    assert all("host=" not in t for t in topics)


# ── control leg: listed is not drained ──────────────────────────────────────

def test_a_message_on_the_v9_topic_is_actually_drained(sc):
    """The control that matters.

    Asserting the V9 name appears in a list proves only that a string was
    built. This asserts the reader REACHES it: a consult sitting on the V9
    topic and nowhere else must come back from `pending()`. Without this leg
    the suite would pass on a widening that readers ignore — the same shape as
    a check that stops being consulted (L-555).

    Injected through `pending(reader=…)`, the seam the function already
    exposes, rather than by patching a private name.
    """
    circuit, inbox, _ = sc
    v9 = circuit.v9_topic_for_circuit(circuit.circuit_id("agent"))
    asked = []

    def reader(topic, cursor, limit=100, **kw):
        asked.append(topic)
        if topic != v9:
            return []
        return [{"offset": 0, "ts": 1,
                 "metadata": {"client_msg_id": "cm-v9",
                              "conversation_id": "conv-v9",
                              "from_agent": "peer-on-v9"},
                 "payload": "hello from V9"}]

    msgs = inbox.pending(reader=reader)
    assert v9 in asked, "the V9 topic was never even asked for"
    ids = [m.get("client_msg_id") for m in msgs]
    assert "cm-v9" in ids, (
        "a consult on the V9 topic did not reach pending() — the topic is "
        "listed but not drained")
    landed = [m for m in msgs if m["client_msg_id"] == "cm-v9"][0]
    assert landed["topic"] == v9
    assert landed["from"] == "peer-on-v9"


def test_control_the_drain_test_can_fail(sc):
    """Guards the leg above: a reader that returns nothing must NOT pass.

    A drain test whose assertion holds for an empty reader is measuring
    nothing. This proves the previous test's assertion actually bites.
    """
    _, inbox, _ = sc
    msgs = inbox.pending(reader=lambda topic, cursor, limit=100, **kw: [])
    assert [m.get("client_msg_id") for m in msgs] == []


def test_v9_topic_is_read_only_in_this_slice(sc):
    """Slice A changes nothing a peer can observe.

    The send path must still address the T-3433 form. If an outbound address
    ever starts with `aef::`, the write-side cut has happened without the peer
    notification it is gated on.
    """
    circuit, inbox, _ = sc
    outbound = circuit.topic_for_name("010-termlink")
    assert not outbound.startswith("inbox:aef::")
    assert outbound == "inbox:" + circuit.resolve_address("010-termlink")
