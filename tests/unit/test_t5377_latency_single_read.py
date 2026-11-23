"""T-5377 — `fw sidecar latency` reads each ledger once per report.

The old inbound() re-read the whole receiver events log and the receipts-sent
ledger inside its loop over pending messages (pending x log size) and never
returned on a real repo. These tests pin (1) equivalence with the old
algorithm on a hermetic fixture and (2) the single-read shape.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import direct, latency, receipts, receiver  # noqa: E402


def _old_inbound() -> list[dict]:
    """Verbatim pre-T-5377 inbound(): the equivalence oracle."""
    _ts, _secs = latency._ts, latency._secs
    events: dict[str, dict] = {}
    for ev in receiver.read_events():
        events.setdefault(str(ev.get("msg_id")), {}).setdefault(ev.get("event"), ev)
    out = []
    for mid in sorted(set(receiver.list_pending_messages())):
        msg = receiver.read_message(mid) or {}
        via = msg.get("via") or "direct"
        sent = _ts(msg.get("hub_ts")) if via == "hub-topic" else _ts(msg.get("created_at"))
        ev = events.get(mid, {})
        stored = _ts((ev.get("STORED") or {}).get("ts")) or _ts(msg.get("_stored_at"))
        handed = _ts((ev.get("HANDED_OVER") or {}).get("ts"))
        injects = [e for e in receiver.read_events(mid) if e.get("event") == "INJECT_ATTEMPT"]
        replied = [r for r in receipts.read_sent()
                   if r.get("client_msg_id") == mid and r.get("state") == receipts.REPLIED and r.get("ok")]
        out.append({
            "send_to_replied_s": _secs(sent, _ts(replied[0]["ts"])) if replied else None,
            "msg_id": mid, "from": msg.get("from"), "via": via,
            "urgent": bool(msg.get("urgent")),
            "sent_at": sent.isoformat() if sent else None,
            "send_to_received_s": _secs(sent, stored),
            "send_to_handed_over_s": _secs(sent, handed),
            "inject_triggers": [e.get("trigger") for e in injects if e.get("ok")],
        })
    return out


def _jsonl(path: Path, rows) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(r) + "\n" for r in rows) + "not json\n", encoding="utf-8")


@pytest.fixture
def project(tmp_path, monkeypatch):
    root = tmp_path / "lat-proj"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: lat-proj\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    sc = root / ".context" / "sidecar"
    msgs = sc / "receiver" / "messages"
    msgs.mkdir(parents=True)

    def msg(mid, **env):
        (msgs / f"{mid}.json").write_text(json.dumps(env), encoding="utf-8")
        (msgs / f"{mid}.ready").write_text("", encoding="utf-8")

    msg("m-a", **{"from": "peer1", "created_at": "2026-11-23T10:00:00+00:00", "urgent": True})
    msg("m-b", **{"from": "peer2", "via": "hub-topic", "hub_ts": 1763892000000})
    msg("m-c", **{"from": "peer1", "created_at": "2026-11-23T11:00:00Z",
                  "_stored_at": "2026-11-23T11:00:04Z"})
    msg("m-d", **{"from": "peer3"})                      # no send time at all
    (msgs / "m-torn.json").write_text("{}", encoding="utf-8")   # no .ready: not pending

    _jsonl(sc / "receiver" / "events.jsonl", [
        {"msg_id": "m-a", "event": "STORED", "ts": "2026-11-23T10:00:01+00:00"},
        {"msg_id": "m-a", "event": "STORED", "ts": "2026-11-23T10:09:00+00:00"},  # later dup ignored
        {"msg_id": "m-a", "event": "INJECT_ATTEMPT", "ok": True, "trigger": "idle"},
        {"msg_id": "m-a", "event": "INJECT_ATTEMPT", "ok": False, "trigger": "busy"},
        {"msg_id": "m-a", "event": "INJECT_ATTEMPT", "ok": True, "trigger": "hook"},
        {"msg_id": "m-a", "event": "HANDED_OVER", "ts": "2026-11-23T10:00:30+00:00"},
        {"msg_id": "m-b", "event": "STORED", "ts": "2025-11-23T10:00:05+00:00"},
        {"msg_id": "m-b", "event": "INJECT_ATTEMPT", "ok": True, "trigger": "timer"},
        {"msg_id": "m-zz", "event": "STORED", "ts": "2026-11-23T10:00:01+00:00"},
        {"msg_id": 7, "event": "INJECT_ATTEMPT", "ok": True, "trigger": "nonstr"},
        {"event": "STORED", "ts": "2026-11-23T10:00:01+00:00"},
    ])
    _jsonl(sc / "receipts-sent.jsonl", [
        {"client_msg_id": "m-a", "state": "REPLIED", "ok": False, "ts": "2026-11-23T10:00:40+00:00"},
        {"client_msg_id": "m-a", "state": "REPLIED", "ok": True, "ts": "2026-11-23T10:01:00+00:00"},
        {"client_msg_id": "m-a", "state": "REPLIED", "ok": True, "ts": "2026-11-23T10:05:00+00:00"},
        {"client_msg_id": "m-a", "state": "HANDED_OVER", "ok": True, "ts": "2026-11-23T10:00:02+00:00"},
        {"client_msg_id": "m-c", "state": "REPLIED", "ok": True, "ts": "2026-11-23T11:02:00Z"},
    ])
    _jsonl(sc / "direct-ack.jsonl", [
        {"client_msg_id": "o-1", "state": direct.SENT, "target": "peer1", "ts": "2026-11-23T09:00:00Z"},
        {"client_msg_id": "o-1", "state": direct.RECEIVED, "ts": "2026-11-23T09:00:01Z"},
        {"client_msg_id": "o-1", "state": direct.HANDED_OVER, "ts": "2026-11-23T09:00:20Z"},
        {"client_msg_id": "o-2", "state": direct.SENT, "target": "peer2", "ts": "2026-11-23T09:10:00Z"},
    ])
    _jsonl(sc / "receipts.jsonl", [
        {"client_msg_id": "h-1", "state": receipts.RECEIVED, "ts": "2026-11-23T08:00:03Z"},
        {"client_msg_id": "h-1", "state": receipts.REPLIED, "ts": "2026-11-23T08:10:00Z"},
    ])
    ob = sc / "outbox"
    ob.mkdir(parents=True)
    (ob / "h-1.json").write_text(json.dumps({"client_msg_id": "h-1", "to": "peer9",
                                             "created_at": "2026-11-23T08:00:00Z"}))
    (ob / "o-1.json").write_text(json.dumps({"client_msg_id": "o-1", "to": "peer1"}))
    return root


def test_report_equals_old_algorithm(project):
    new = latency.report()
    old_in = _old_inbound()
    assert new["inbound"]["messages"] == old_in
    assert [m["msg_id"] for m in old_in] == ["m-a", "m-b", "m-c", "m-d"]
    a = old_in[0]
    assert a["send_to_received_s"] == 1.0 and a["send_to_handed_over_s"] == 30.0
    assert a["send_to_replied_s"] == 60.0 and a["inject_triggers"] == ["idle", "hook"]
    assert old_in[2]["send_to_replied_s"] == 120.0
    # Whole report, both sides, against the old inbound spliced into report().
    orig = latency.inbound
    try:
        latency.inbound = _old_inbound
        expected = latency.report()
    finally:
        latency.inbound = orig
    assert new == expected
    assert latency.render(new) == latency.render(expected)
    assert {m["client_msg_id"] for m in new["outbound"]["messages"]} == {"o-1", "o-2", "h-1"}


def test_each_ledger_read_once_per_report(project, monkeypatch):
    counts: dict[str, int] = {}

    def counting(mod, name):
        real = getattr(mod, name)

        def wrapper(*a, **kw):
            key = f"{mod.__name__.rsplit('.', 1)[-1]}.{name}"
            counts[key] = counts.get(key, 0) + 1
            return real(*a, **kw)
        monkeypatch.setattr(mod, name, wrapper)

    counting(receiver, "read_events")
    counting(receipts, "read_sent")
    counting(receipts, "read_ledger")
    counting(direct, "read_ledger")
    latency.report()
    assert counts.get("receiver.read_events") == 1, counts
    assert counts.get("receipts.read_sent") == 1, counts
    assert counts.get("receipts.read_ledger") == 1, counts
    assert counts.get("direct.read_ledger") == 1, counts
