"""T-3434 — the sidecar sweep as the retry ladder's first consumer (D-600).

T-3418 shipped this sweep as `resolve_expired` on a 5-minute cron: a
past-deadline STORED row was flipped to UNKNOWN and never re-sent, because
retry policy (OBS-447) was still the operator's to rule. D-600 ruled it, so
these tests pin the sweep that WORKS the ladder instead of recording its
failures — re-post, escalate, dead-letter — with time injected throughout so
a 76-day ladder is exercised in milliseconds.
"""

import importlib
import json
from datetime import datetime, timedelta, timezone

import pytest

T0 = datetime(2026, 9, 22, 12, 0, 0, tzinfo=timezone.utc)


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "sweeper-test")
    import lib.sidecar.outbox as outbox
    import lib.sidecar.delivery as delivery
    import lib.sidecar.inbox as inbox
    import lib.sidecar.retry as retry
    import lib.sidecar.status as status
    import lib.sidecar_cli as cli
    for m in (outbox, delivery, inbox, retry, status, cli):
        importlib.reload(m)
    return cli, outbox, status, retry, delivery


def _ok_probe(_hub):
    import lib.sidecar.delivery as delivery
    return delivery.ProbeResult(True)


def _recorder():
    posted = []
    return posted, lambda msg: posted.append(msg)


def _empty_reader(_topic, _cursor, _limit=None):
    return []


def _reply_reader(conversation_id, sender="agentB"):
    def reader(_topic, _cursor, _limit=None):
        return [{"offset": 0, "metadata": {"conversation_id": conversation_id,
                                           "from_agent": sender,
                                           "client_msg_id": "reply-1"},
                 "payload": "answered"}]
    return reader


def _store_and_fail(outbox, delivery, *, to="agentB", conversation="conv-1",
                    at=T0):
    """A message whose first attempt failed at the transport. -> STORED."""
    cmid = outbox.write_message(from_id="sweeper-test", to=to, body="the question",
                                conversation_id=conversation)

    def boom(_msg):
        raise delivery.TransportError("hub down")

    delivery.deliver(cmid, boom, _ok_probe, now=at)
    return cmid


def _store_and_deliver(outbox, delivery, *, to="agentB", conversation="conv-1",
                       at=T0):
    """A message the hub accepted. -> INJECTED_NOW, and still on the ladder."""
    cmid = outbox.write_message(from_id="sweeper-test", to=to, body="the question",
                                conversation_id=conversation)
    delivery.deliver(cmid, lambda _m: None, _ok_probe, now=at)
    return cmid


# ── the un-posted class: re-post on the rung ─────────────────────────────────

def test_a_row_before_its_rung_is_not_touched(sc):
    _cli, outbox, _status, retry, delivery = sc
    cmid = _store_and_fail(outbox, delivery)
    posted, transport = _recorder()

    report = retry.sweep(now=T0 + timedelta(seconds=59), transport=transport,
                         probe=_ok_probe, reader=_empty_reader)

    assert report["considered"] == 1 and report["due"] == 0
    assert posted == []
    assert outbox.latest_ack_state(cmid)["attempts"] == 1


def test_unposted_row_is_reposted_exactly_when_its_rung_comes_due(sc):
    _cli, outbox, _status, retry, delivery = sc
    cmid = _store_and_fail(outbox, delivery)
    posted, transport = _recorder()

    report = retry.sweep(now=T0 + timedelta(seconds=60), transport=transport,
                         probe=_ok_probe, reader=_empty_reader)

    assert report["reposted"] == 1
    assert len(posted) == 1 and posted[0]["client_msg_id"] == cmid
    row = outbox.latest_ack_state(cmid)
    assert row["attempts"] == 2 and row["rung"] == 0
    assert row["state"] == outbox.INJECTED_NOW


def test_a_repost_that_fails_again_advances_to_the_next_rung(sc):
    _cli, outbox, _status, retry, delivery = sc
    cmid = _store_and_fail(outbox, delivery)

    def boom(_msg):
        raise delivery.TransportError("still down")

    retry.sweep(now=T0 + timedelta(seconds=60), transport=boom,
                probe=_ok_probe, reader=_empty_reader)
    row = outbox.latest_ack_state(cmid)
    assert row["state"] == outbox.STORED and row["attempts"] == 2 and row["rung"] == 0

    # Attempt 3 is the first on rung 1, so it is due 5 minutes after attempt 2
    # — not 5 minutes after the original send.
    assert row["next_retry_at"] == (T0 + timedelta(seconds=360)).isoformat()
    retry.sweep(now=T0 + timedelta(seconds=359), transport=boom,
                probe=_ok_probe, reader=_empty_reader)
    assert outbox.latest_ack_state(cmid)["attempts"] == 2, "not due yet"

    retry.sweep(now=T0 + timedelta(seconds=360), transport=boom,
                probe=_ok_probe, reader=_empty_reader)
    row = outbox.latest_ack_state(cmid)
    assert row["attempts"] == 3 and row["rung"] == 1


def test_sweep_advances_rungs_correctly_across_simulated_time(sc):
    """The worked example: one un-posted row walked from attempt 1 to dead-letter."""
    _cli, outbox, _status, retry, delivery = sc
    import lib.retry_ladder as rl
    cmid = _store_and_fail(outbox, delivery)

    def boom(_msg):
        raise delivery.TransportError("hub down for the whole ladder")

    now = T0
    seen_rungs = []
    for attempt in range(2, rl.MAX_ATTEMPTS + 1):
        row = outbox.latest_ack_state(cmid)
        now = datetime.fromisoformat(row["next_retry_at"])
        retry.sweep(now=now, transport=boom, probe=_ok_probe, reader=_empty_reader)
        row = outbox.latest_ack_state(cmid)
        assert row["attempts"] == attempt, f"attempt {attempt} not recorded"
        seen_rungs.append(row["rung"])

    # Every rung visited, twice each, in order — the ladder D-600 ruled.
    assert seen_rungs == [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7]
    assert outbox.latest_ack_state(cmid)["next_retry_at"] is None

    # One more sweep past the last rung: dead-letter.
    report = retry.sweep(now=now + timedelta(days=60), transport=boom,
                         probe=_ok_probe, reader=_empty_reader)
    assert report["deadlettered"] == 1
    row = outbox.latest_ack_state(cmid)
    assert row["state"] == outbox.UNKNOWN
    assert row["error"] == "ladder-exhausted"
    assert row["attempts"] == rl.MAX_ATTEMPTS


def test_a_dead_lettered_row_is_closed_and_never_swept_again(sc):
    _cli, outbox, _status, retry, delivery = sc
    cmid = _store_and_fail(outbox, delivery)
    outbox.record_ack(cmid, "agentB", None, outbox.UNKNOWN,
                      error="ladder-exhausted", attempts=16)

    report = retry.sweep(now=T0 + timedelta(days=200), transport=_recorder()[1],
                         probe=_ok_probe, reader=_empty_reader)
    assert report["considered"] == 0


# ── the posted-but-unread class: escalate, do not re-post ────────────────────

def test_posted_row_escalates_to_a_nudge_from_the_fifteen_minute_rung(sc):
    _cli, outbox, _status, retry, delivery = sc
    cmid = _store_and_deliver(outbox, delivery)
    posted, transport = _recorder()

    # Fast-forward the ledger to attempt 4 (next attempt is 5 = rung 2).
    outbox.record_ack(cmid, "agentB", None, outbox.INJECTED_NOW, attempts=4,
                      rung=2, next_retry_at=(T0 + timedelta(minutes=15)).isoformat())

    report = retry.sweep(now=T0 + timedelta(minutes=15), transport=transport,
                         probe=_ok_probe, reader=_empty_reader)

    assert report["nudged"] == 1 and report["reposted"] == 0
    # What went on the wire is a POINTER, not the original body re-sent.
    assert len(posted) == 1
    assert posted[0]["client_msg_id"] != cmid
    assert "[nudge]" in posted[0]["body"] and cmid in posted[0]["body"]
    assert "the question" not in posted[0]["body"]

    row = outbox.latest_ack_state(cmid)
    assert row["state"] == outbox.INJECTED_NOW, "escalation must not change ack state"
    assert row["attempts"] == 5 and row["rung"] == 2
    assert row["error"].startswith("escalated:nudge")


def test_posted_row_surfaces_to_the_operator_from_the_one_day_rung(sc):
    _cli, outbox, _status, retry, delivery = sc
    cmid = _store_and_deliver(outbox, delivery)
    posted, transport = _recorder()
    notices = []

    outbox.record_ack(cmid, "agentB", None, outbox.INJECTED_NOW, attempts=10,
                      rung=5, next_retry_at=(T0 + timedelta(days=1)).isoformat())

    report = retry.sweep(now=T0 + timedelta(days=1), transport=transport,
                         probe=_ok_probe, reader=_empty_reader,
                         operator_notice=lambda msg, rung, attempts:
                             notices.append((msg["client_msg_id"], rung, attempts))
                             or "operator-notice-sent")

    assert report["operator"] == 1 and report["nudged"] == 0 and report["reposted"] == 0
    assert notices == [(cmid, 5, 11)]
    assert posted == [], "the operator rung does not touch the hub"
    row = outbox.latest_ack_state(cmid)
    assert row["attempts"] == 11 and row["rung"] == 5
    assert row["error"].startswith("escalated:operator")


def test_posted_row_still_reposts_on_the_first_two_rungs(sc):
    """Before the 15-minute rung there is nothing to escalate — re-post."""
    _cli, outbox, _status, retry, delivery = sc
    cmid = _store_and_deliver(outbox, delivery)
    posted, transport = _recorder()

    report = retry.sweep(now=T0 + timedelta(seconds=60), transport=transport,
                         probe=_ok_probe, reader=_empty_reader)

    assert report["reposted"] == 1 and report["nudged"] == 0
    assert posted[0]["client_msg_id"] == cmid, "same id — the receiver dedupes it"


# ── a message that was read: no duplicates on the hub ────────────────────────

def test_no_duplicates_on_the_hub_for_a_message_that_was_read(sc):
    _cli, outbox, _status, retry, delivery = sc
    cmid = _store_and_deliver(outbox, delivery, conversation="conv-answered")
    posted, transport = _recorder()

    report = retry.sweep(now=T0 + timedelta(days=1), transport=transport,
                         probe=_ok_probe,
                         reader=_reply_reader("conv-answered"))

    assert posted == [], "a replied conversation must never be re-posted or nudged"
    assert report["answered"] == 1
    assert report["reposted"] == 0 and report["nudged"] == 0
    row = outbox.latest_ack_state(cmid)
    assert row["error"].startswith("answered")
    assert row["next_retry_at"] is None

    # And it stays closed on every later sweep.
    again = retry.sweep(now=T0 + timedelta(days=30), transport=transport,
                        probe=_ok_probe, reader=_empty_reader)
    assert again["considered"] == 0 and posted == []


def test_our_own_echo_does_not_count_as_a_reply(sc):
    _cli, outbox, _status, retry, delivery = sc
    _store_and_deliver(outbox, delivery, conversation="conv-echo")
    posted, transport = _recorder()

    report = retry.sweep(now=T0 + timedelta(seconds=60), transport=transport,
                         probe=_ok_probe,
                         reader=_reply_reader("conv-echo", sender="sweeper-test"))

    assert report["answered"] == 0 and report["reposted"] == 1


def test_sweep_never_advances_the_inbox_cursor(sc):
    """`fw sidecar inbox` owns that cursor; a sweep must not consume consults."""
    _cli, outbox, _status, retry, delivery = sc
    import lib.sidecar.inbox as inbox
    _store_and_deliver(outbox, delivery, conversation="conv-peek")
    before = json.dumps(inbox.load_state(), sort_keys=True)

    retry.sweep(now=T0 + timedelta(days=1), transport=_recorder()[1],
                probe=_ok_probe, reader=_reply_reader("conv-peek"))

    assert json.dumps(inbox.load_state(), sort_keys=True) == before


# ── legacy and unretryable rows ──────────────────────────────────────────────

def test_a_pre_t3434_row_joins_the_ladder_at_rung_0(sc):
    """Rows written before the ladder existed have no `attempts` field."""
    _cli, outbox, _status, retry, delivery = sc
    cmid = outbox.write_message(from_id="sweeper-test", to="agentB", body="legacy",
                                conversation_id="conv-legacy")
    # The T-3418-era shape: state + deadline, no ladder fields.
    row = {"client_msg_id": cmid, "target": "agentB", "hub": None,
           "state": outbox.STORED, "deadline": (T0 + timedelta(seconds=30)).isoformat(),
           "error": "transport-failed: legacy", "ts": T0.isoformat()}
    with open(outbox._ledger_path(), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(row) + "\n")

    posted, transport = _recorder()
    report = retry.sweep(now=T0 + timedelta(seconds=60), transport=transport,
                         probe=_ok_probe, reader=_empty_reader)

    assert report["reposted"] == 1, "a legacy row must not be dead-lettered on sight"
    assert len(posted) == 1
    assert outbox.latest_ack_state(cmid)["attempts"] == 2


def test_a_row_whose_message_file_is_gone_is_dead_lettered(sc):
    _cli, outbox, _status, retry, delivery = sc
    cmid = _store_and_fail(outbox, delivery)
    (outbox._outbox_dir() / f"{cmid}.json").unlink()

    report = retry.sweep(now=T0 + timedelta(seconds=60), transport=_recorder()[1],
                         probe=_ok_probe, reader=_empty_reader)

    assert report["deadlettered"] == 1
    row = outbox.latest_ack_state(cmid)
    assert row["state"] == outbox.UNKNOWN
    assert row["error"].startswith("ladder-unretryable")


# ── the CLI surface the cron calls ───────────────────────────────────────────

def test_clean_sweep_is_not_an_error(sc, capsys):
    cli, _outbox, _status, _retry, _delivery = sc
    rc = cli.main(["sweep"])
    assert rc == 0
    assert "0 open row(s)" in capsys.readouterr().out


def test_cli_sweep_passes_now_through_and_reports_every_verb(sc, capsys, monkeypatch):
    """The cron's surface: `--now` reaches the sweep, the report reaches stdout."""
    cli, _outbox, _status, retry, _delivery = sc
    seen = {}

    def fake_sweep(**kwargs):
        seen.update(kwargs)
        return {"considered": 3, "due": 2, "reposted": 1, "nudged": 1,
                "operator": 0, "deadlettered": 0, "answered": 0,
                "actions": [{"client_msg_id": "m1", "verb": "repost",
                             "reason": "ok"}]}

    monkeypatch.setattr(retry, "sweep", fake_sweep)
    stamp = (T0 + timedelta(seconds=60)).isoformat()

    rc = cli.main(["sweep", "--json", "--now", stamp])
    out = json.loads(capsys.readouterr().out)

    assert rc == 0
    assert seen["now"] == stamp
    assert set(out) >= {"considered", "due", "reposted", "nudged", "operator",
                        "deadlettered", "answered", "actions"}

    rc = cli.main(["sweep", "--now", stamp])
    text = capsys.readouterr().out
    assert rc == 0
    assert "1 reposted" in text and "1 nudged" in text and "m1" in text


def test_a_delivery_made_before_the_ladder_existed_is_not_adopted(sc):
    """34 such rows were live when the ladder shipped; none may be re-opened."""
    _cli, outbox, _status, retry, _delivery = sc
    cmid = outbox.write_message(from_id="sweeper-test", to="agentB", body="old",
                                conversation_id="conv-ancient")
    row = {"client_msg_id": cmid, "target": "agentB", "hub": None,
           "state": outbox.INJECTED_NOW, "deadline": None, "error": None,
           "ts": (T0 - timedelta(days=30)).isoformat()}
    with open(outbox._ledger_path(), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(row) + "\n")

    posted, transport = _recorder()
    report = retry.sweep(now=T0, transport=transport, probe=_ok_probe,
                         reader=_empty_reader)

    assert report["considered"] == 0
    assert posted == []
