"""T-3417 — arc-011 sidecar status: out-of-band observer (round-1 review Δ4)."""

import importlib
import subprocess
from datetime import datetime, timedelta, timezone

import pytest


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "agent-under-test")
    import lib.sidecar.outbox as outbox
    import lib.sidecar.delivery as delivery
    import lib.sidecar.inbox as inbox
    import lib.sidecar.status as status
    for m in (outbox, delivery, inbox, status):
        importlib.reload(m)
    return status, delivery, outbox, inbox


def _ok_transport(msg):
    return None


def _failing_transport(msg):
    from lib.sidecar.delivery import TransportError
    raise TransportError("connection refused")


def test_empty_state_is_all_zeros(sc):
    status, *_ = sc
    snap = status.snapshot()
    assert snap["messages_total"] == 0
    assert snap["pending"] == 0
    assert set(snap["ledger"].values()) == {0}
    assert snap["expired_unswept"] == 0
    assert snap["last_send"] is None
    assert snap["last_delivery"] is None
    assert snap["agent_id"] == "agent-under-test"


def test_counts_after_a_mixed_ledger(sc):
    status, delivery, outbox, _ = sc
    ok = outbox.write_message("a", "b", "delivered one", "c1")
    delivery.deliver(ok, _ok_transport)
    bad = outbox.write_message("a", "b", "dropped one", "c2")
    delivery.deliver(bad, _failing_transport)

    snap = status.snapshot()
    assert snap["messages_total"] == 2
    assert snap["pending"] == 1  # the failed one still carries its flag
    assert snap["ledger"][outbox.INJECTED_NOW] == 1
    assert snap["ledger"][outbox.STORED] == 1
    assert snap["expired_unswept"] == 0  # its 30s deadline has not passed
    assert snap["last_send"] is not None
    assert snap["last_delivery"] is not None


def test_silent_drop_becomes_visible_once_its_deadline_passes(sc):
    """The exact shape the review said was invisible: failed, and nothing swept it."""
    status, delivery, outbox, _ = sc
    bad = outbox.write_message("a", "b", "dropped", "c1")
    delivery.deliver(bad, _failing_transport)

    later = datetime.now(timezone.utc) + timedelta(minutes=5)
    snap = status.snapshot(now=later)
    assert snap["expired_unswept"] == 1
    assert snap["ledger"][outbox.STORED] == 1

    # Once a sweep runs, it is no longer "unswept" — it is UNKNOWN, on the record.
    outbox.resolve_expired(now=later.isoformat())
    snap = status.snapshot(now=later)
    assert snap["expired_unswept"] == 0
    assert snap["ledger"][outbox.UNKNOWN] == 1


def test_snapshot_never_touches_the_hub(sc, monkeypatch):
    status, delivery, outbox, _ = sc
    outbox.write_message("a", "b", "x", "c1")

    def boom(*a, **k):
        raise AssertionError("snapshot() called out of process")
    monkeypatch.setattr(subprocess, "run", boom)
    monkeypatch.setattr(subprocess, "Popen", boom)

    snap = status.snapshot()  # must not raise
    assert snap["messages_total"] == 1


def test_inbox_cursor_is_reported_per_topic(sc):
    status, _, _, inbox = sc
    state = inbox.load_state()
    state["topics"]["sidecar:agent-under-test"] = {"cursor": 7, "seen": []}
    inbox.save_state(state)

    snap = status.snapshot()
    assert snap["inbox_cursors"] == {"sidecar:agent-under-test": 7}
    assert "sidecar:agent-under-test@7" in status.render(snap)
