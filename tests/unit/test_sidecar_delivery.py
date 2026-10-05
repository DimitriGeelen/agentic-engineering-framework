"""T-3404 — arc-011 sidecar uniform delivery transport (T-3397 Amendment 5, slice 2)."""

import importlib

import pytest


@pytest.fixture()
def sidecar(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    import lib.sidecar.outbox as outbox
    import lib.sidecar.delivery as delivery
    importlib.reload(outbox)
    importlib.reload(delivery)
    return delivery, outbox


REMOTE = "1389a831016c4bf1"


def _store(outbox, hub=None, to="agentB"):
    # T-3887: since T-3855 a row with a remote hub always carries a full
    # circuit (addressing.resolve). A bare name + remote hub is the legacy
    # pre-1.8.2 shape, refused by deliver — tests that want it ask explicitly.
    if hub and "/" not in to:
        to = f"{REMOTE}/{to}"
    return outbox.write_message(from_id="agentA", to=to, body="hi",
                                conversation_id="conv-1", hub=hub)


def _store_legacy(outbox, hub, to="ring20-manager"):
    return outbox.write_message(from_id="agentA", to=to, body="hi",
                                conversation_id="conv-1", hub=hub)


def test_t3887_legacy_bare_name_with_remote_hub_is_never_posted(sidecar):
    """ring20-manager: a 1.8.0 row (bare to + remote hub) was re-posted by every
    sweep into the SENDER's own hub inbox, where nobody reads it."""
    delivery, outbox = sidecar
    cmid = _store_legacy(outbox, hub="ring20-management")
    sent, transport = _recording_transport()
    probed = []
    result = delivery.deliver(cmid, transport, lambda h: probed.append(h) or delivery.ProbeResult(ok=True))
    assert sent == [] and probed == []
    assert result.delivered is False and result.state == outbox.UNKNOWN
    row = outbox.latest_ack_state(cmid)
    assert row["state"] == outbox.UNKNOWN
    assert row["error"].startswith("ladder-unretryable: pre-T-3855 address")
    assert "fw sidecar send --to ring20-manager --hub ring20-management" in row["error"]
    assert cmid not in outbox.list_pending()


def test_t3887_circuit_row_and_local_bare_row_are_still_posted(sidecar):
    delivery, outbox = sidecar
    remote = outbox.write_message(from_id="agentA", to=f"{REMOTE}/ring20-dashboard",
                                  body="hi", conversation_id="c", hub="ring20-dashboard")
    local = _store(outbox, hub=None, to="agentB")
    sent, transport = _recording_transport()
    assert delivery.deliver(remote, transport).delivered is True
    assert delivery.deliver(local, transport).delivered is True
    assert len(sent) == 2


def _recording_transport():
    sent = []
    return sent, lambda msg: sent.append(msg)


def test_deliver_posts_and_records_terminal_transition(sidecar):
    delivery, outbox = sidecar
    cmid = _store(outbox)
    sent, transport = _recording_transport()

    result = delivery.deliver(cmid, transport)

    assert result.delivered is True
    assert result.state == outbox.INJECTED_NOW
    assert len(sent) == 1
    assert sent[0]["client_msg_id"] == cmid
    assert outbox.latest_ack_state(cmid)["state"] == outbox.INJECTED_NOW


def test_same_host_and_cross_host_take_the_same_path(sidecar):
    """hub is data on one path, not a branch: None is the degenerate case."""
    delivery, outbox = sidecar
    seen_hubs = []

    def probe(hub):
        seen_hubs.append(hub)
        return delivery.ProbeResult(ok=True)

    same_host = _store(outbox, hub=None)
    cross_host = _store(outbox, hub="192.168.10.122:9100")
    sent, transport = _recording_transport()

    r_same = delivery.deliver(same_host, transport, probe)
    r_cross = delivery.deliver(cross_host, transport, probe)

    # Identical outcome shape for both.
    assert (r_same.delivered, r_same.state) == (r_cross.delivered, r_cross.state)
    # The probe gate ran for the local hub too, not just the remote one.
    assert seen_hubs == [None, "192.168.10.122:9100"]
    # And the hub travelled through to the ledger unchanged in both cases.
    assert outbox.latest_ack_state(same_host)["hub"] is None
    assert outbox.latest_ack_state(cross_host)["hub"] == "192.168.10.122:9100"


def test_failed_precondition_refuses_before_any_post(sidecar):
    delivery, outbox = sidecar
    cmid = _store(outbox, hub="192.168.10.199:9100")
    sent, transport = _recording_transport()

    def refusing_probe(hub):
        return delivery.ProbeResult(ok=False, reason="below version floor")

    result = delivery.deliver(cmid, transport, refusing_probe)

    assert result.delivered is False
    assert sent == []  # never attempted — the gate is before the post
    row = outbox.latest_ack_state(cmid)
    assert row["state"] == outbox.STORED  # non-terminal
    assert "hub-refused" in row["error"]
    assert "below version floor" in row["error"]


def test_transport_failure_is_loud_non_terminal_and_retryable(sidecar):
    delivery, outbox = sidecar
    cmid = _store(outbox)

    def failing_transport(msg):
        raise delivery.TransportError("connection refused")

    result = delivery.deliver(cmid, failing_transport)

    assert result.delivered is False
    row = outbox.latest_ack_state(cmid)
    assert row["state"] == outbox.STORED
    assert row["state"] not in outbox.TERMINAL_STATES  # no silent promotion
    assert "transport-failed" in row["error"]
    assert row["deadline"] is not None  # sweepable, not stuck forever
    assert cmid in outbox.list_pending()  # still outstanding work

    # Caller-owned retry, same client_msg_id — the documented recovery.
    sent, working_transport = _recording_transport()
    retry = delivery.deliver(cmid, working_transport)

    assert retry.delivered is True
    assert sent[0]["client_msg_id"] == cmid  # idempotent on the receiving side
    assert outbox.latest_ack_state(cmid)["state"] == outbox.INJECTED_NOW


def test_successful_delivery_consumes_the_flag(sidecar):
    delivery, outbox = sidecar
    cmid = _store(outbox)
    assert cmid in outbox.list_pending()
    sent, transport = _recording_transport()

    delivery.deliver(cmid, transport)

    assert cmid not in outbox.list_pending()
    assert not delivery._flag_path(cmid).exists()
    assert delivery._message_path(cmid).exists()  # record kept
    assert outbox.latest_ack_state(cmid)["state"] in outbox.TERMINAL_STATES


def test_slow_path_records_injected_later(sidecar):
    delivery, outbox = sidecar
    cmid = _store(outbox)
    sent, transport = _recording_transport()

    result = delivery.deliver(cmid, transport, fast_path=False)

    assert result.state == outbox.INJECTED_LATER
    assert outbox.latest_ack_state(cmid)["state"] == outbox.INJECTED_LATER


# ── T-3434: the universal retry ladder's fields on every row ──────────────────

def test_deliver_records_attempt_1_and_schedules_rung_0(sidecar):
    delivery, outbox = sidecar
    from datetime import datetime, timezone
    cmid = _store(outbox)
    _sent, transport = _recording_transport()
    at = datetime(2026, 9, 22, 12, 0, tzinfo=timezone.utc)

    delivery.deliver(cmid, transport, now=at)

    row = outbox.latest_ack_state(cmid)
    assert row["attempts"] == 1
    assert row["rung"] == 0
    # A delivered message is still scheduled: the hub took it, nobody read it
    # yet, and unread is D-600's second failure class.
    assert row["next_retry_at"] == "2026-09-22T12:01:00+00:00"


def test_a_failed_delivery_carries_the_same_ladder_fields(sidecar):
    delivery, outbox = sidecar
    from datetime import datetime, timezone
    cmid = _store(outbox)

    def boom(_msg):
        raise delivery.TransportError("hub down")

    delivery.deliver(cmid, boom, now=datetime(2026, 9, 22, 12, 0, tzinfo=timezone.utc))

    row = outbox.latest_ack_state(cmid)
    assert row["state"] == outbox.STORED
    assert row["attempts"] == 1 and row["rung"] == 0
    assert row["next_retry_at"] == "2026-09-22T12:01:00+00:00"
    assert "transport-failed" in row["error"]


def test_a_retry_passes_its_own_attempt_number_and_gets_the_next_rung(sidecar):
    delivery, outbox = sidecar
    from datetime import datetime, timezone
    cmid = _store(outbox)
    _sent, transport = _recording_transport()

    # attempt 3 sits on rung 1 (the 5-minute rung).
    delivery.deliver(cmid, transport, attempts=3,
                     now=datetime(2026, 9, 22, 12, 0, tzinfo=timezone.utc))

    row = outbox.latest_ack_state(cmid)
    assert row["attempts"] == 3 and row["rung"] == 1
    assert row["next_retry_at"] == "2026-09-22T12:05:00+00:00"


def test_the_last_attempt_schedules_nothing(sidecar):
    delivery, outbox = sidecar
    cmid = _store(outbox)
    _sent, transport = _recording_transport()

    delivery.deliver(cmid, transport, attempts=16)  # ladder exhausted after 16

    row = outbox.latest_ack_state(cmid)
    assert row["attempts"] == 16
    # `rung` looks backward — attempt 16 was made on the last rung — while
    # `next_retry_at` looks forward, and there is no forward left.
    assert row["rung"] == 7
    assert row["next_retry_at"] is None
