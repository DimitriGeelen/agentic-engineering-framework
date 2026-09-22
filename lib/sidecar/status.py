"""arc-011 sidecar — out-of-band status of the consult channel.

T-3417, slice 6. The SEQ-T3411 round-1 value review classed the sidecar
`D — unmeasured`: tests prove correctness in isolation, and "a channel cannot
report its own failures". This module is the observer that finding asked
for, and its one design rule is that it reads **our own durable state** —
the outbox files, the append-only ack ledger, the inbox cursor — and never
asks the hub. A hub that answers "delivered" (TermLink's own
`confirmed: false` shape, measured in T-3405) cannot move these numbers,
because nothing here listens to it.

What each number is derived from:
  messages_total     outbox/*.json          — every write_message() ever
  pending            outbox flag ∩ message   — written, not yet delivered
  ledger[state]      latest ledger row/id    — the current ack state of each
  expired_unswept    STORED + deadline<now   — the silent-drop shape: failed
                                                or stuck, and nothing swept it
  last_send          max created_at          — from the message files
  last_delivery      max ts of INJECTED_*    — from the ledger
  inbox_cursors      inbox-state.json        — what we have read, per topic
"""

from __future__ import annotations

import json
from datetime import datetime, timezone

from . import inbox, outbox


def _iso(dt: datetime | None) -> str | None:
    return dt.isoformat() if dt else None


def _parse(ts: str | None) -> datetime | None:
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts)
    except ValueError:
        return None


def _max(a: datetime | None, b: datetime | None) -> datetime | None:
    if a is None:
        return b
    if b is None:
        return a
    return max(a, b)


def snapshot(now: datetime | None = None) -> dict:
    """Channel state from durable files only. Makes no call to the hub."""
    now_dt = now or datetime.now(timezone.utc)

    outbox_dir = outbox._outbox_dir()
    messages = list(outbox_dir.glob("*.json"))
    last_send: datetime | None = None
    for path in messages:
        try:
            with open(path, encoding="utf-8") as fh:
                last_send = _max(last_send, _parse(json.load(fh).get("created_at")))
        except (OSError, json.JSONDecodeError):
            continue

    latest: dict[str, dict] = {}
    for row in outbox._read_ledger():
        cmid = row.get("client_msg_id")
        if cmid:
            latest[cmid] = row

    per_state = {s: 0 for s in (outbox.STORED, outbox.INJECTED_NOW,
                                outbox.INJECTED_LATER, outbox.UNKNOWN)}
    expired_unswept = 0
    last_delivery: datetime | None = None
    for row in latest.values():
        state = row.get("state")
        if state in per_state:
            per_state[state] += 1
        if state in (outbox.INJECTED_NOW, outbox.INJECTED_LATER):
            last_delivery = _max(last_delivery, _parse(row.get("ts")))
        if state == outbox.STORED:
            deadline = _parse(row.get("deadline"))
            if deadline and now_dt > deadline:
                expired_unswept += 1

    cursors = {topic: entry.get("cursor", 0)
               for topic, entry in inbox.load_state().get("topics", {}).items()}

    return {
        "agent_id": inbox.agent_id(),
        "inbox_topic": inbox.inbox_topic(),
        "messages_total": len(messages),
        "pending": len(outbox.list_pending()),
        "ledger": per_state,
        "expired_unswept": expired_unswept,
        "last_send": _iso(last_send),
        "last_delivery": _iso(last_delivery),
        "inbox_cursors": cursors,
        "as_of": _iso(now_dt),
    }


def render(snap: dict) -> str:
    led = snap["ledger"]
    lines = [
        f"agent:            {snap['agent_id']}   (inbox {snap['inbox_topic']})",
        f"messages total:   {snap['messages_total']}   pending: {snap['pending']}",
        f"ack ledger:       STORED {led[outbox.STORED]}  INJECTED_NOW {led[outbox.INJECTED_NOW]}"
        f"  INJECTED_LATER {led[outbox.INJECTED_LATER]}  UNKNOWN {led[outbox.UNKNOWN]}",
        f"expired unswept:  {snap['expired_unswept']}"
        + ("   <-- failed or stuck, and nothing has swept them" if snap["expired_unswept"] else ""),
        f"last send:        {snap['last_send'] or '-'}",
        f"last delivery:    {snap['last_delivery'] or '-'}",
    ]
    if snap["inbox_cursors"]:
        lines.append("inbox cursors:    " + ", ".join(
            f"{t}@{c}" for t, c in sorted(snap["inbox_cursors"].items())))
    return "\n".join(lines)
