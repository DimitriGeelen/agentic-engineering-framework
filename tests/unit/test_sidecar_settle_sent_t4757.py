"""T-4757 — a sender settles its own outstanding consult (`fw sidecar settle-sent`).

055's finding: the retry ladder (lib/sidecar/retry.py) closed a row only on
peer-side evidence (answered / read / notice) or by dead-lettering it after 16
attempts. A sender that knew a consult was answered out of band, or obsolete,
could not stop it being re-posted, nudged and finally dead-lettered. These
tests run against a fixture ledger in tmp_path, never the live sidecar state.
"""

import importlib
import json
from datetime import datetime, timedelta, timezone

import pytest

T0 = datetime(2026, 10, 26, 12, 0, 0, tzinfo=timezone.utc)


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "settler-test")
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_HOST", "host107.ring20.lan")
    import lib.sidecar.outbox as outbox
    import lib.sidecar.delivery as delivery
    import lib.sidecar.inbox as inbox
    import lib.sidecar.retry as retry
    import lib.sidecar.status as status
    import lib.sidecar.waiting as waiting
    import lib.sidecar_cli as cli
    for m in (outbox, delivery, inbox, retry, status, waiting, cli):
        importlib.reload(m)
    return cli, outbox, retry, delivery, waiting


def _ok_probe(_hub):
    import lib.sidecar.delivery as delivery
    return delivery.ProbeResult(True)


def _empty_reader(_topic, _cursor, _limit=None):
    return []


def _delivered(outbox, delivery, *, sender="settler-test"):
    cmid = outbox.write_message(from_id=sender, to="agentB", body="the question",
                                conversation_id="conv-1")
    delivery.deliver(cmid, lambda _m: None, _ok_probe, now=T0)
    return cmid


def _sweep(retry, at, nudges):
    return retry.sweep(now=at, transport=lambda _m: None, probe=_ok_probe,
                       reader=_empty_reader,
                       nudge=lambda msg, *_a, **_k: nudges.append(msg) or "nudge-sent",
                       operator_notice=lambda *_a: "operator-notice-sent")


def _ledger_lines(outbox):
    return outbox._ledger_path().read_text(encoding="utf-8").splitlines()


def test_unsettled_consult_is_nudged_control(sc):
    """Control leg: without a settle, the 15-minute rung nudges the peer."""
    _cli, outbox, retry, delivery, _w = sc
    _delivered(outbox, delivery)
    nudges = []
    for minutes in (1, 6, 21, 60):
        _sweep(retry, T0 + timedelta(minutes=minutes), nudges)
    assert nudges, "the ladder must nudge an unanswered posted consult"


def test_settle_stops_the_nudge_and_never_deadletters(sc):
    _cli, outbox, retry, delivery, _w = sc
    cmid = _delivered(outbox, delivery)

    row = retry.settle_sent(cmid, "answered out of band on the termlink chat")
    assert row["settled_by"] == "settler-test"
    assert row["reason"] == "answered out of band on the termlink chat"
    assert row["error"].startswith(retry.SETTLED)
    assert row["ts"]
    assert not retry.is_open(outbox.latest_ack_state(cmid))

    nudges = []
    at = T0
    for _ in range(40):   # far past the 16-attempt ladder
        at += timedelta(days=3)
        report = _sweep(retry, at, nudges)
        assert report["deadlettered"] == 0
    assert nudges == []
    latest = outbox.latest_ack_state(cmid)
    assert latest["state"] != outbox.UNKNOWN
    assert latest["error"].startswith(retry.SETTLED)


def test_settle_posts_nothing_to_the_peer(sc, monkeypatch):
    _cli, outbox, retry, delivery, _w = sc
    cmid = _delivered(outbox, delivery)
    import lib.sidecar.termlink_transport as tl
    monkeypatch.setattr(tl, "termlink_transport",
                        lambda _m: pytest.fail("settle must not post"))
    retry.settle_sent(cmid, "obsolete")


def test_unknown_id_refused(sc):
    _cli, outbox, retry, delivery, _w = sc
    _delivered(outbox, delivery)
    with pytest.raises(retry.SettleRefusal, match="no outstanding consult"):
        retry.settle_sent("00000000-not-a-real-id", "obsolete")


def test_foreign_id_refused(sc):
    _cli, outbox, retry, delivery, _w = sc
    cmid = _delivered(outbox, delivery, sender="someone-else")
    before = _ledger_lines(outbox)
    with pytest.raises(retry.SettleRefusal, match="not this agent's"):
        retry.settle_sent(cmid, "obsolete")
    assert _ledger_lines(outbox) == before


def test_double_settle_refused(sc):
    _cli, outbox, retry, delivery, _w = sc
    cmid = _delivered(outbox, delivery)
    retry.settle_sent(cmid, "obsolete")
    before = _ledger_lines(outbox)
    with pytest.raises(retry.SettleRefusal, match="already settled"):
        retry.settle_sent(cmid, "obsolete again")
    assert _ledger_lines(outbox) == before


def test_empty_reason_refused(sc):
    _cli, outbox, retry, delivery, _w = sc
    cmid = _delivered(outbox, delivery)
    with pytest.raises(retry.SettleRefusal, match="reason"):
        retry.settle_sent(cmid, "  ")


def test_ledger_is_append_only(sc):
    _cli, outbox, retry, delivery, _w = sc
    cmid = _delivered(outbox, delivery)
    before = _ledger_lines(outbox)
    retry.settle_sent(cmid, "obsolete")
    after = _ledger_lines(outbox)
    assert after[:len(before)] == before
    assert len(after) == len(before) + 1
    assert json.loads(after[-1])["client_msg_id"] == cmid


def test_settle_closes_it_in_the_waiting_register(sc):
    _cli, outbox, retry, delivery, waiting = sc
    cmid = _delivered(outbox, delivery)
    retry.settle_sent(cmid, "obsolete")
    closures = waiting._closures()
    assert cmid in closures
    assert closures[cmid]["by"] == "sender:settler-test"


def test_cli_verb_settles_and_refuses(sc, capsys):
    cli, outbox, retry, delivery, _w = sc
    cmid = _delivered(outbox, delivery)
    assert cli.main(["settle-sent", cmid, "--reason", "obsolete"]) == 0
    assert "settled" in capsys.readouterr().out
    assert not retry.is_open(outbox.latest_ack_state(cmid))
    assert cli.main(["settle-sent", cmid, "--reason", "again"]) == 1
    assert "already settled" in capsys.readouterr().err


def test_status_does_not_count_a_settled_row_as_overdue(sc):
    _cli, outbox, retry, delivery, _w = sc
    import lib.sidecar.status as status
    importlib.reload(status)
    cmid = outbox.write_message(from_id="settler-test", to="agentB", body="q",
                                conversation_id="conv-2")

    def boom(_m):
        raise delivery.TransportError("hub down")

    delivery.deliver(cmid, boom, _ok_probe, now=T0)
    retry.settle_sent(cmid, "obsolete")
    snap = status.snapshot(now=T0 + timedelta(days=30))
    assert snap["expired_unswept"] == 0
