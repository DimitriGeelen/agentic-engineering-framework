"""T-3404 — arc-011 sidecar uniform delivery transport (T-3397 Amendment 5, slice 2)."""

import importlib

import pytest


@pytest.fixture()
def sidecar(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    import lib.sidecar.outbox as outbox
    import lib.sidecar.delivery as delivery
    importlib.reload(outbox)
    importlib.reload(delivery)
    return delivery, outbox


def _store(outbox, hub=None, to="agentB"):
    return outbox.write_message(from_id="agentA", to=to, body="hi",
                                conversation_id="conv-1", hub=hub)


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
