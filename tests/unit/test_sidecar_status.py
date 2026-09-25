"""T-3417 — arc-011 sidecar status: out-of-band observer (round-1 review Δ4)."""

import importlib
import subprocess
from datetime import datetime, timedelta, timezone

import pytest


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    project = tmp_path / "999-Agentic-Engineering-Framework"
    project.mkdir(exist_ok=True)
    monkeypatch.setenv("FRAMEWORK_ROOT", str(project))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "agent-under-test")
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_HOST", "host107.ring20.lan")
    monkeypatch.delenv("FW_FOCUS_SESSION_KEY", raising=False)
    monkeypatch.delenv("TERMLINK_SESSION", raising=False)
    import lib.sidecar.outbox as outbox
    import lib.sidecar.circuit as circuit
    import lib.sidecar.delivery as delivery
    import lib.sidecar.inbox as inbox
    import lib.sidecar.status as status
    for m in (outbox, circuit, delivery, inbox, status):
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


# ── T-3433: the status names both addresses ─────────────────────────────────

HUB = "cacc73ea32b121dd"
PROJ = "999-Agentic-Engineering-Framework"


def test_snapshot_reports_the_circuit_and_every_drained_topic(sc):
    """T-3479 widened this from two topics to three (V9 dual-read).

    The assertion is deliberately NOT "three topics": it is that the observer
    reports exactly what the readers drain. Pinning a count would have to be
    edited again at the next address change, and an observer that needs editing
    to stay truthful is the defect this test exists to catch.
    """
    status, _, _, inbox = sc
    snap = status.snapshot()
    assert snap["circuit_id"] == f"{HUB}/{PROJ}/agent-under-test"
    assert snap["inbox_topics"] == inbox.read_topics()
    assert snap["inbox_topic"] == snap["inbox_topics"][0]
    # The specific addresses still matter — identity, not just agreement.
    assert f"inbox:{HUB}/{PROJ}/agent-under-test" in snap["inbox_topics"]
    assert "sidecar:agent-under-test" in snap["inbox_topics"]
    assert any(t.startswith("inbox:aef::") for t in snap["inbox_topics"])


def test_status_topics_do_not_assert_a_host(sc):
    """The V9 topic is SPARSE — hub and project only.

    This is the property that reconciles T-3433 with arc-020: V9 without a
    `host=` token carries the same information as the circuit form and claims
    nothing about where a peer runs. If a `host=` ever appears here, the
    convergence has quietly re-adopted the serialization T-3433 rejected.
    """
    status, _, _, _ = sc
    v9 = [t for t in status.snapshot()["inbox_topics"] if t.startswith("inbox:aef::")]
    assert v9, "no V9 topic present — dual-read is not wired"
    for topic in v9:
        assert "host=" not in topic


def test_render_lists_a_cursor_for_every_drained_topic_even_unread(sc):
    """A topic missing from the cursor map is a topic nobody is watching —
    so both are listed at 0 rather than omitted."""
    status, _, _, _ = sc
    text = status.render(status.snapshot())
    assert f"inbox:{HUB}/{PROJ}/agent-under-test@0" in text
    assert "sidecar:agent-under-test@0" in text


def test_status_still_renders_when_the_hub_anchor_is_unestablished(sc, monkeypatch):
    """The unreachable-hub case IS the state status exists to report; raising
    would hide every other number on the page."""
    status, _, _, _ = sc
    import lib.sidecar.circuit as circuit
    monkeypatch.delenv("FW_SIDECAR_HUB_ID", raising=False)
    monkeypatch.setattr(circuit, "_hub_cache", None)
    monkeypatch.setattr(circuit, "hub_id",
                        lambda **kw: (_ for _ in ()).throw(circuit.CircuitError("no hub")))
    snap = status.snapshot()
    assert snap["circuit_id"] is None
    assert "hub anchor unestablished" in status.render(snap)


def test_whoami_prints_the_circuit_and_both_topics(sc, capsys):
    import lib.sidecar_cli as cli
    import importlib
    importlib.reload(cli)
    assert cli.main(["whoami"]) == 0
    out = capsys.readouterr().out
    assert f"circuit:       {HUB}/{PROJ}/agent-under-test" in out
    assert f"//host107.ring20.lan/{HUB}/{PROJ}/agent-under-test" in out
    assert f"inbox topic:   inbox:{HUB}/{PROJ}/agent-under-test" in out
    assert "legacy (read): sidecar:agent-under-test" in out


def test_whoami_json_carries_every_form(sc, capsys):
    import json as _json
    import importlib
    import lib.sidecar_cli as cli
    importlib.reload(cli)
    assert cli.main(["whoami", "--json"]) == 0
    payload = _json.loads(capsys.readouterr().out)
    assert payload["project_circuit"] == f"{HUB}/{PROJ}"
    assert payload["circuit_id_full"].startswith("//host107.ring20.lan/")
    assert payload["legacy_topics"] == ["sidecar:agent-under-test"]
