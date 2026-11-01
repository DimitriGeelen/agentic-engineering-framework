"""T-4962 — the live sidecar self-test is never a consult the retry ladder chases.

055-agentic-fleet-cockpit (msg de1569c0) found `e2e-<run>` self-test messages in its
real outbox, reposted and escalated as "unanswered after 14 attempts". The sweep now
releases any message on an `e2e-` conversation (released, not dead-lettered), on the
first sweep whether or not a rung is due; a normal consult beside it is still chased.
All state lives in a temp PROJECT_ROOT; the live sidecar is never touched (T-4315).
"""

import importlib
from datetime import datetime, timedelta, timezone

import pytest

T0 = datetime(2026, 11, 1, 12, 0, 0, tzinfo=timezone.utc)


@pytest.fixture()
def sc(tmp_path, monkeypatch):
    (tmp_path / ".context").mkdir()
    (tmp_path / ".framework.yaml").write_text("project_name: e2e-a\n")
    monkeypatch.setenv("FRAMEWORK_ROOT", str(tmp_path))
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "e2e-a")
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    for k in ("NTFY_ENABLED", "FW_SIDECAR_NOTIFY_CMD"):
        monkeypatch.delenv(k, raising=False)
    from lib.sidecar import delivery, inbox, outbox, receipts, retry
    for m in (outbox, delivery, inbox, receipts, retry):
        importlib.reload(m)
    return {"outbox": outbox, "delivery": delivery, "retry": retry}


def _ok_probe(_hub):
    from lib.sidecar import delivery
    return delivery.ProbeResult(True)


def _empty_reader(_topic, _cursor, _limit=None):
    return []


def _send(sc, conversation, *, posted=True):
    cmid = sc["outbox"].write_message(from_id="e2e-a", to="agentB", body="ping",
                                      conversation_id=conversation)

    def boom(_m):
        raise sc["delivery"].TransportError("hub down")
    sc["delivery"].deliver(cmid, (lambda _m: None) if posted else boom, _ok_probe, now=T0)
    return cmid


@pytest.mark.parametrize("days", [0, 40])
def test_e2e_messages_are_released_and_a_normal_consult_is_still_chased(sc, days):
    ob, retry = sc["outbox"], sc["retry"]
    e2e_posted = _send(sc, "e2e-1fc080c8")
    e2e_stored = _send(sc, "e2e-a4ef8725", posted=False)
    ctrl = _send(sc, "conv-normal", posted=False)
    acted = []
    report = retry.sweep(now=T0 + timedelta(days=days, hours=2), transport=acted.append,
                         probe=_ok_probe, reader=_empty_reader,
                         nudge=lambda msg, *a, **k: acted.append(msg) or "x",
                         operator_notice=lambda msg, *a, **k: acted.append(msg) or "x")
    assert report["released"] == 2
    for cmid, conv in ((e2e_posted, "e2e-1fc080c8"), (e2e_stored, "e2e-a4ef8725")):
        row = ob.latest_ack_state(cmid)
        assert not retry.is_open(row)
        assert row["error"] == f"{retry.RELEASED}: e2e self-test {conv}"
        assert row["state"] != ob.UNKNOWN                 # not a dead-letter
    touched = {m["client_msg_id"] for m in acted}
    assert e2e_posted not in touched and e2e_stored not in touched
    assert ctrl in touched                                 # the control is reposted
    assert report["deadlettered"] == 0


def test_a_conversation_merely_containing_e2e_is_not_released(sc):
    retry = sc["retry"]
    cmid = _send(sc, "review-e2e-results", posted=False)
    report = retry.sweep(now=T0 + timedelta(hours=2), transport=lambda _m: None,
                         probe=_ok_probe, reader=_empty_reader)
    assert report["released"] == 0
    assert any(a["client_msg_id"] == cmid for a in report["actions"])
