"""T-3544 / OBS-567 — the inbound consult backlog must be countable without
being consumed.

Fixture shape mirrors test_sidecar_dm.py's `mod` (same FRAMEWORK_ROOT sandbox /
reload dance), because `unread_summary` sits in `inbox.py` beside the cursor
store both of them share.

The load-bearing test in this file is `test_summary_does_not_drain_what_it
_measures`, together with its control. Everything else here checks arithmetic;
that pair checks that the alarm does not destroy its own subject — the
OBS-566/T-3539 shape, where a diagnostic killed the thing it was diagnosing.
"""

import base64
import importlib

import pytest

HUB = "cacc73ea32b121dd"
AGENT = "999-Agentic-Engineering-Framework"

#: 2026-09-28T12:00:00Z in ms, so ages below are exact rather than approximate.
BASE_MS = 1790592000000


@pytest.fixture()
def mod(tmp_path, monkeypatch):
    project = tmp_path / AGENT
    project.mkdir(exist_ok=True)
    monkeypatch.setenv("FRAMEWORK_ROOT", str(project))
    monkeypatch.setenv("PROJECT_ROOT", str(project))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", HUB)
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", AGENT)
    import lib.sidecar.outbox as outbox
    import lib.sidecar.inbox as inbox
    importlib.reload(outbox)
    importlib.reload(inbox)
    return inbox


def _now(_mod=None):
    """The fixed clock every age assertion below is measured against."""
    from datetime import datetime, timezone
    return datetime.fromtimestamp(BASE_MS / 1000, tz=timezone.utc)


def _env(offset, *, body="need an answer", sender="832-Workflow-designer",
         cmid=None, age_hours=0.0):
    """One hub envelope, aged `age_hours` BEFORE the fixed `now`."""
    return {
        "offset": offset,
        "metadata": {
            "from_agent": sender,
            "client_msg_id": cmid or f"cmid-{offset}",
            "conversation_id": "conv-1",
        },
        "payload_b64": base64.b64encode(body.encode()).decode(),
        "ts": int(BASE_MS - age_hours * 3600 * 1000),
    }


def _reader_for(by_topic):
    """A reader keyed per topic, so alias-topic behaviour is testable."""
    def reader(topic, cursor, limit=100):
        return [e for e in by_topic.get(topic, []) if e["offset"] >= cursor][:limit]
    return reader


def _primary(mod):
    return mod.inbox_topic()


# ── counting ─────────────────────────────────────────────────────────────────

def test_empty_inbox_reports_zero_not_absence(mod):
    snap = mod.unread_summary(reader=_reader_for({}), now=_now(mod))
    assert snap["unread"] == 0
    assert snap["topics"] == []


def test_counts_unread_and_names_the_oldest_sender(mod):
    topic = _primary(mod)
    reader = _reader_for({topic: [
        _env(0, age_hours=1.0, sender="010-termlink"),
        _env(1, age_hours=9.0, sender="832-Workflow-designer"),
        _env(2, age_hours=3.0, sender="010-termlink"),
    ]})
    snap = mod.unread_summary(reader=reader, now=_now(mod))
    assert snap["unread"] == 3
    row = snap["topics"][0]
    assert row["topic"] == topic
    assert row["unread"] == 3
    assert row["age_hours"] == 9.0
    # The WARN names a peer, so the summary must name the peer who has waited
    # LONGEST — not whoever happens to be first in offset order.
    assert row["oldest_from"] == "832-Workflow-designer"


def test_duplicate_client_msg_ids_are_not_double_counted(mod):
    """The number the WARN reports must equal the number `fw sidecar inbox`
    will show. A sender retrying past the hub's ~5-minute dedupe TTL delivers
    twice; pending() collapses that, so this must too."""
    topic = _primary(mod)
    reader = _reader_for({topic: [
        _env(0, cmid="same", age_hours=6.0),
        _env(1, cmid="same", age_hours=5.0),
        _env(2, cmid="other", age_hours=5.0),
    ]})
    assert mod.unread_summary(reader=reader, now=_now(mod))["unread"] == 2


def test_alias_topics_are_reported_separately(mod):
    """`read_topics()` covers the circuit topic, its V9 spelling and the legacy
    `sidecar:` alias. A consult on any of them is owed work."""
    topics = mod.read_topics()
    assert len(topics) >= 2
    reader = _reader_for({topics[0]: [_env(0, age_hours=2.0)],
                          topics[-1]: [_env(0, cmid="legacy", age_hours=8.0)]})
    snap = mod.unread_summary(reader=reader, now=_now(mod))
    assert snap["unread"] == 2
    assert {r["topic"] for r in snap["topics"]} == {topics[0], topics[-1]}


def test_cursor_is_respected_so_a_drained_inbox_reports_zero(mod):
    topic = _primary(mod)
    envelopes = [_env(0, age_hours=9.0), _env(1, age_hours=8.0)]
    reader = _reader_for({topic: envelopes})
    assert mod.unread_summary(reader=reader, now=_now(mod))["unread"] == 2
    mod.pending(reader=reader, advance=True)          # the operator acts on it
    assert mod.unread_summary(reader=reader, now=_now(mod))["unread"] == 0


# ── the load-bearing pair: the check must not consume its own subject ────────

def test_summary_does_not_drain_what_it_measures(mod):
    """OBS-567's whole point. `pending()` advances cursors and the shared
    seen-set by default; a summary built on that default would consume the
    consult it was reporting, so the second run of `fw doctor` would go quiet
    with the peer still waiting."""
    topic = _primary(mod)
    reader = _reader_for({topic: [_env(0, age_hours=9.0), _env(1, age_hours=8.0)]})
    mod.save_state({"topics": {topic: {"cursor": 0}}, "seen": []})
    before = mod._state_path().read_bytes()

    mod.unread_summary(reader=reader, now=_now(mod))
    mod.unread_stale(0, reader=reader, now=_now(mod))

    assert mod._state_path().read_bytes() == before, \
        "the backlog check moved the cursor — it consumed the consult it reported"
    # And the consults are still there to be read.
    assert mod.unread_summary(reader=reader, now=_now(mod))["unread"] == 2


def test_control_leg_an_advancing_read_really_does_mutate_the_state(mod):
    """Without this, the test above passes against a build where the reader is
    never called at all — proving nothing. This pins that the byte-comparison
    is capable of failing."""
    topic = _primary(mod)
    reader = _reader_for({topic: [_env(0, age_hours=9.0)]})
    mod.save_state({"topics": {topic: {"cursor": 0}}, "seen": []})
    before = mod._state_path().read_bytes()

    mod.pending(reader=reader, advance=True)          # the mutant

    assert mod._state_path().read_bytes() != before, \
        "advance=True left the state file untouched — the comparison is blind"


# ── staleness threshold ─────────────────────────────────────────────────────

def test_stale_filters_by_age(mod):
    topic = _primary(mod)
    reader = _reader_for({topic: [_env(0, age_hours=2.0)]})
    assert mod.unread_stale(4, reader=reader, now=_now(mod)) == []
    assert len(mod.unread_stale(1, reader=reader, now=_now(mod))) == 1


def test_stale_reports_an_unread_consult_of_unknown_age(mod):
    """A consult whose envelope carries no usable timestamp is still owed work.
    Dropping it would reproduce exactly the blindness this check exists to end,
    so it is reported with age_hours None rather than filtered out."""
    topic = _primary(mod)
    bad = _env(0)
    bad["ts"] = None
    rows = mod.unread_stale(24, reader=_reader_for({topic: [bad]}), now=_now(mod))
    assert len(rows) == 1
    assert rows[0]["age_hours"] is None
    assert rows[0]["unread"] == 1


def test_stale_is_empty_when_nothing_is_unread(mod):
    assert mod.unread_stale(0, reader=_reader_for({}), now=_now(mod)) == []
