"""arc-011 sidecar — `fw sidecar latency`: how long until RECEIVED and HANDED_OVER.

T-3684. Operator, 2026-10-02: "responding it has been received should take
place pretty quick." This measures it from the ledgers, never from a claim:

OUTBOUND (messages WE sent)
  direct path — our sender ledger .context/sidecar/direct-ack.jsonl:
    send→RECEIVED     SENT row ts → RECEIVED row ts  (CONFIRM-1, the HTTP answer)
    send→HANDED_OVER  SENT row ts → HANDED_OVER row ts (CONFIRM-2 from the peer)
    send→REPLIED      SENT row ts → REPLIED row ts
  hub path — our outbox message's created_at → the peer's receipt rows in
  .context/sidecar/receipts.jsonl (lib/sidecar/receipts.py), same three legs.

INBOUND (messages our receiver holds, .context/sidecar/receiver/)
    send→RECEIVED     the sender's send time → our STORED event
    send→HANDED_OVER  the sender's send time → our HANDED_OVER event
  The send time is the envelope's `created_at` (direct path, same-host clock)
  or the hub's own post timestamp `hub_ts` (legacy topic path). For a hub
  message "RECEIVED" is the watcher's ingest — the moment our sidecar had it.

A message with no HANDED_OVER yet contributes to send→RECEIVED only, and is
counted as `open`. Summary per leg: n, median, p95, max (seconds).
"""

from __future__ import annotations

import json
import math
from datetime import datetime, timezone

from . import direct, outbox, receipts, receiver


def _ts(value) -> datetime | None:
    if value in (None, ""):
        return None
    if isinstance(value, (int, float)):
        v = float(value)
        return datetime.fromtimestamp(v / 1000 if v > 1e11 else v, tz=timezone.utc)
    try:
        dt = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _secs(a: datetime | None, b: datetime | None) -> float | None:
    if a is None or b is None:
        return None
    return round((b - a).total_seconds(), 3)


def summarise(values: list[float]) -> dict:
    vals = sorted(v for v in values if v is not None)
    if not vals:
        return {"n": 0, "median": None, "p95": None, "max": None}
    n = len(vals)
    mid = vals[n // 2] if n % 2 else (vals[n // 2 - 1] + vals[n // 2]) / 2
    p95 = vals[min(n - 1, max(0, math.ceil(0.95 * n) - 1))]
    return {"n": n, "median": round(mid, 3), "p95": round(p95, 3), "max": round(vals[-1], 3)}


def outbound() -> list[dict]:
    first: dict[str, dict] = {}
    for row in direct.read_ledger():
        cid = str(row.get("client_msg_id") or "")
        first.setdefault(cid, {})
        first[cid].setdefault(row.get("state"), row)
    out = []
    for cid, states in first.items():
        sent = states.get(direct.SENT)
        if not sent:
            continue
        t0 = _ts(sent.get("ts"))
        out.append({
            "client_msg_id": cid, "to": sent.get("target"), "path": "direct",
            "sent_at": sent.get("ts"),
            "send_to_received_s": _secs(t0, _ts((states.get(direct.RECEIVED) or {}).get("ts"))),
            "send_to_handed_over_s": _secs(t0, _ts((states.get(direct.HANDED_OVER) or {}).get("ts"))),
            "send_to_replied_s": _secs(t0, _ts((states.get(direct.REPLIED) or {}).get("ts"))),
        })
    # Hub-path sends: our outbox message + the peer's receipts.
    rc: dict[str, dict] = {}
    for r in receipts.read_ledger():
        rc.setdefault(str(r.get("client_msg_id")), {}).setdefault(r.get("state"), r)
    try:
        files = sorted(outbox._outbox_dir().glob("*.json"))
    except OSError:
        files = []
    for f in files:
        try:
            msg = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        cid = str(msg.get("client_msg_id") or f.stem)
        if cid in first:
            continue
        t0 = _ts(msg.get("created_at"))
        got = rc.get(cid, {})
        out.append({
            "client_msg_id": cid, "to": msg.get("to"), "path": "hub",
            "sent_at": msg.get("created_at"),
            "send_to_received_s": _secs(t0, _ts((got.get(receipts.RECEIVED) or {}).get("ts"))),
            "send_to_handed_over_s": _secs(t0, _ts((got.get(receipts.HANDED_OVER) or {}).get("ts"))),
            "send_to_replied_s": _secs(t0, _ts((got.get(receipts.REPLIED) or {}).get("ts"))),
        })
    return out


def inbound() -> list[dict]:
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


def report() -> dict:
    o, i = outbound(), inbound()
    def side(ms):
        return {"messages": ms,
                "send_to_received": summarise([m["send_to_received_s"] for m in ms]),
                "send_to_handed_over": summarise([m["send_to_handed_over_s"] for m in ms]),
                "send_to_replied": summarise([m["send_to_replied_s"] for m in ms]),
                "open": sum(1 for m in ms if m["send_to_handed_over_s"] is None)}
    return {"outbound": side(o), "inbound": side(i)}


def render(rep: dict) -> str:
    lines = []
    for side in ("outbound", "inbound"):
        r = rep[side]
        lines.append(f"{side} ({len(r['messages'])} message(s), {r['open']} without HANDED_OVER)")
        for leg in ("send_to_received", "send_to_handed_over", "send_to_replied"):
            s = r[leg]
            if not s["n"]:
                lines.append(f"  {leg.replace('_', ' '):<22} n=0")
            else:
                lines.append(f"  {leg.replace('_', ' '):<22} n={s['n']:<4} median={s['median']}s "
                             f"p95={s['p95']}s max={s['max']}s")
        for m in r["messages"][-20:]:
            ident = m.get("client_msg_id") or m.get("msg_id")
            extra = f" via={m['via']}" if "via" in m else f" path={m.get('path')}"
            lines.append(f"    {ident[:36]:<36} recv={m['send_to_received_s']}s "
                         f"handed_over={m['send_to_handed_over_s']}s "
                         f"replied={m['send_to_replied_s']}s{extra}")
    return "\n".join(lines)
