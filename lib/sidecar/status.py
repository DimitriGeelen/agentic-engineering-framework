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
  expired_unswept    next_retry_at < now     — the silent-drop shape: a rung
                                                came due and no sweep worked
                                                it (T-3434; legacy rows with
                                                no ladder fields fall back to
                                                STORED + deadline < now)
  dead_letters       UNKNOWN + ladder-* error — the ladder gave up: 16
                                                attempts spent, or the
                                                message file went missing
  last_send          max created_at          — from the message files
  last_delivery      max ts of INJECTED_*    — from the ledger
  inbox_cursors      inbox-state.json        — what we have read, per topic
"""

from __future__ import annotations

import json
from datetime import datetime, timezone

from . import circuit, inbox, outbox


def _iso(dt: datetime | None) -> str | None:
    return dt.isoformat() if dt else None


def _parse(ts: str | None) -> datetime | None:
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts)
    except ValueError:
        return None


def _circuit_or_none(level: str) -> str | None:
    """A circuit, or None when the hub anchor cannot be established. Status
    must still render on a host with no reachable hub — that IS the state it
    exists to report, and raising here would hide every other number."""
    try:
        return circuit.circuit_id(level)
    except circuit.CircuitError:
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
    dead_letters = 0
    last_delivery: datetime | None = None
    for row in latest.values():
        state = row.get("state")
        error = row.get("error") or ""
        if state in per_state:
            per_state[state] += 1
        if state in (outbox.INJECTED_NOW, outbox.INJECTED_LATER):
            last_delivery = _max(last_delivery, _parse(row.get("ts")))
        if state == outbox.UNKNOWN and error.startswith("ladder-"):
            dead_letters += 1
            continue
        if error.startswith("answered") or state == outbox.UNKNOWN:
            continue  # the ladder is finished with this row
        # T-3434: the ladder, not the 30-second transport deadline, is what a
        # sweep is late against. Before the ladder the deadline WAS the retry
        # trigger; now a STORED row is legitimately held for a rung's worth of
        # time with its deadline long past, so testing the deadline here would
        # report every in-flight message as a missed sweep.
        due = _parse(row.get("next_retry_at"))
        if due is None and row.get("attempts") is None:
            due = _parse(row.get("deadline")) if state == outbox.STORED else None
        if due and now_dt > due:
            expired_unswept += 1

    cursors = {topic: entry.get("cursor", 0)
               for topic, entry in inbox.load_state().get("topics", {}).items()}

    # Same reason as _circuit_or_none: an unreachable hub is the state this
    # observer exists to report, so it degrades to the legacy alias rather
    # than raising and hiding every other number.
    try:
        topics = [inbox.inbox_topic()] + inbox.legacy_topics()
    except circuit.CircuitError:
        topics = inbox.legacy_topics()
    return {
        "agent_id": inbox.agent_id(),
        "circuit_id": _circuit_or_none("agent"),
        "inbox_topic": topics[0],
        "inbox_topics": topics,
        "messages_total": len(messages),
        "pending": len(outbox.list_pending()),
        "ledger": per_state,
        "expired_unswept": expired_unswept,
        "dead_letters": dead_letters,
        "last_send": _iso(last_send),
        "last_delivery": _iso(last_delivery),
        "inbox_cursors": cursors,
        "as_of": _iso(now_dt),
    }


def render(snap: dict) -> str:
    led = snap["ledger"]
    lines = [
        f"agent:            {snap['agent_id']}",
        f"circuit:          {snap.get('circuit_id') or '- (hub anchor unestablished)'}",
        "inbox topics:     " + "\n                  ".join(
            snap.get("inbox_topics") or [snap["inbox_topic"]]),
        f"messages total:   {snap['messages_total']}   pending: {snap['pending']}",
        f"ack ledger:       STORED {led[outbox.STORED]}  INJECTED_NOW {led[outbox.INJECTED_NOW]}"
        f"  INJECTED_LATER {led[outbox.INJECTED_LATER]}  UNKNOWN {led[outbox.UNKNOWN]}",
        f"expired unswept:  {snap['expired_unswept']}"
        + ("   <-- a rung came due and no sweep worked it" if snap["expired_unswept"] else ""),
        f"dead letters:     {snap.get('dead_letters', 0)}"
        + ("   <-- the ladder gave up; these reached nobody"
           if snap.get("dead_letters") else ""),
        f"last send:        {snap['last_send'] or '-'}",
        f"last delivery:    {snap['last_delivery'] or '-'}",
    ]
    # Every drained topic is listed, at cursor 0 if it has never been read —
    # a topic missing from the cursor map is a topic nobody is watching.
    cursors = snap["inbox_cursors"]
    listed = {t: cursors.get(t, 0) for t in (snap.get("inbox_topics") or [])}
    listed.update(cursors)
    if listed:
        lines.append("inbox cursors:    " + ", ".join(
            f"{t}@{c}" for t, c in sorted(listed.items())))
    return "\n".join(lines)
