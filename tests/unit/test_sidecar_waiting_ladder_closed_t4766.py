"""T-4766 — `fw sidecar waiting` must not list an outbound consult the retry
ladder already closed.

ring20 be.23: settle-sent refused aed0fdd9 as "not outstanding — the ladder
already closed it (HUB_ACCEPTED: answered: reply on ...)", while waiting listed
the same id as "outbound ... sent escalated: warn,overdue" with a drop hint.
The ack ledger (retry.is_open) is authoritative; waiting must ask it the same
question. Fixture ledgers in tmp_path only — never the live sidecar state.
"""

import importlib
from datetime import datetime, timedelta, timezone

import pytest

T0 = datetime(2026, 10, 26, 12, 0, 0, tzinfo=timezone.utc)


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "waiter-test")
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_HOST", "host107.ring20.lan")
    import lib.sidecar.outbox as outbox
    import lib.sidecar.delivery as delivery
    import lib.sidecar.inbox as inbox
    import lib.sidecar.retry as retry
    import lib.sidecar.waiting as waiting
    for m in (outbox, delivery, inbox, retry, waiting):
        importlib.reload(m)
    waiting.epoch()
    assert str(waiting._dir()).startswith(str(tmp_path))
    return outbox, retry, delivery, waiting


def _ok_probe(_hub):
    import lib.sidecar.delivery as delivery
    return delivery.ProbeResult(True)


def _delivered(outbox, delivery, conv):
    cmid = outbox.write_message(from_id="waiter-test", to="agentB",
                                body="the question", conversation_id=conv)
    delivery.deliver(cmid, lambda _m: None, _ok_probe, now=T0)
    return cmid


def _later():
    return datetime.now(timezone.utc) + timedelta(hours=142)


def _listed(waiting):
    return {i["id"]: i for i in waiting.outbound_items(_later())}


def _close_like_the_ladder(retry, cmid, error):
    """The closing row the sweep writes: exhaustion dead-letters (UNKNOWN),
    every other closure keeps the ack state and annotates `error`."""
    row = retry.latest_rows()[cmid]
    attempts, _r, _d = retry.ladder_position(row)
    exhausted = error.startswith(retry.EXHAUSTED)
    state = retry.outbox.UNKNOWN if exhausted else row.get("state")
    retry._close(cmid, row, attempts, state, retry.EXHAUSTED if exhausted else error)


def test_open_consult_is_listed_with_its_drop_hint_control(sc):
    outbox, retry, delivery, waiting = sc
    cmid = _delivered(outbox, delivery, "conv-open")
    assert retry.is_open(retry.latest_rows()[cmid])
    item = _listed(waiting)[cmid]
    assert item["side"] == "outbound" and item["actions"] == ["drop"]


def test_answered_by_the_ladder_is_not_listed(sc):
    """The ring20 aed0fdd9 shape: HUB_ACCEPTED, error 'answered: reply on <conv>'."""
    outbox, retry, delivery, waiting = sc
    cmid = _delivered(outbox, delivery, "conv-ans")
    _close_like_the_ladder(retry, cmid, f"{retry.ANSWERED}: reply on conv-ans")
    assert cmid not in _listed(waiting)
    assert waiting.find(cmid) is None


@pytest.mark.parametrize("prefix", ["READ", "NOTICE", "RELEASED", "EXHAUSTED"])
def test_every_ladder_closure_is_not_listed(sc, prefix):
    outbox, retry, delivery, waiting = sc
    cmid = _delivered(outbox, delivery, f"conv-{prefix}")
    _close_like_the_ladder(retry, cmid, f"{getattr(retry, prefix)}: fixture")
    assert cmid not in _listed(waiting)


def test_settled_via_settle_sent_is_not_listed(sc):
    outbox, retry, delivery, waiting = sc
    cmid = _delivered(outbox, delivery, "conv-settle")
    retry.settle_sent(cmid, "answered out of band")
    assert cmid not in _listed(waiting)


def test_still_open_consult_keeps_its_escalation(sc):
    outbox, retry, delivery, waiting = sc
    cmid = _delivered(outbox, delivery, "conv-esc")
    waiting._append(waiting.escalations_path(),
                    {"key": f"out:{cmid}", "level": waiting.LEVEL_WARN, "ts": T0.isoformat()})
    assert _listed(waiting)[cmid]["escalated"] == [waiting.LEVEL_WARN]


def test_settle_sent_and_waiting_agree_on_every_fixture_row(sc):
    """settle-sent accepts exactly the ids waiting lists (and refuses the rest)."""
    outbox, retry, delivery, waiting = sc
    open_ids = [_delivered(outbox, delivery, f"conv-o{i}") for i in range(2)]
    closed = {}
    for name in ("ANSWERED", "READ", "NOTICE", "RELEASED", "EXHAUSTED"):
        cmid = _delivered(outbox, delivery, f"conv-{name}")
        _close_like_the_ladder(retry, cmid, f"{getattr(retry, name)}: fixture")
        closed[name] = cmid
    listed = set(_listed(waiting))
    for cmid in open_ids + list(closed.values()):
        try:
            retry.settle_sent(cmid, "agreement check")
            accepted = True
        except retry.SettleRefusal:
            accepted = False
        assert accepted == (cmid in listed), cmid
    assert listed >= set(open_ids)
    assert not listed & set(closed.values())
