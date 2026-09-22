"""arc-011 sidecar — the retry ladder's first consumer (T-3434, D-600).

Before this module the 5-minute `sidecar-sweep-5m` cron called
`outbox.resolve_expired`, which flipped a past-deadline STORED row to UNKNOWN
and never re-sent: "the sidecar never re-sends on its own; retry policy is
OBS-447, the operator's". OBS-447 has since been ruled (D-600), so the sweep
stops recording failures and starts working them.

**What the sweep walks.** Every message whose latest ledger row is still
*open*, which is narrower than "not terminal in the ack state machine":

    UNKNOWN                         closed — already dead-lettered
    error starts with "answered"    closed — a reply arrived on the
                                    conversation, so there is nothing left
                                    to chase
    everything else                 open

Note what that includes: `INJECTED_NOW` / `INJECTED_LATER` are terminal *ack*
states and still open *ladder* positions. The hub taking a message is not the
recipient reading it, and unread-after-delivery is precisely D-600's second
failure class. The ack state machine is untouched — ladder position lives in
the `attempts` / `rung` / `next_retry_at` row fields (T-3434, `outbox.record_ack`).

**Two classes, two verbs** (`retry_ladder.verb_for`):

    un-posted (STORED)   -> repost on every rung. The recipient holds
                            nothing; sending again is the only move.
    posted, unread       -> repost on rungs 0-1, then escalate: nudge the
                            recipient's inbox from the 15-minute rung,
                            surface to the operator from the 1-day rung.

    exhausted (16 attempts) -> dead-letter: state UNKNOWN, error
                            `ladder-exhausted`, counted by the audit rail.

**One hub read per sweep.** Reply detection walks *our own* inbox topic once
and collects the conversation ids anyone has answered on; each due row then
tests membership. It is a peek — it never advances the inbox cursor, because
`fw sidecar inbox` owns that cursor and a sweep must not consume an agent's
unread consults.

**Legacy rows join at rung 0.** A row written before T-3434 has no `attempts`
field. It is read as one attempt made at its own `ts`, so it enters the ladder
at rung 0 rather than being dead-lettered for having been written early.

**A nudge does not get its own ladder.** The pointer message is posted and
then recorded against the ORIGINAL message's id. Giving escalations their own
ladder entries would multiply them geometrically.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from datetime import datetime, timezone

from .. import retry_ladder
from . import delivery, inbox, outbox

#: Error prefix marking a row the ladder has finished with because the peer
#: answered. Kept in `error` because that field is already the ledger's
#: annotation channel (T-3404) and adding a state would change the three-state
#: machine, which this task deliberately does not.
ANSWERED = "answered"
#: Error prefix marking a row the ladder has deliberately let go of without
#: either succeeding or giving up — it was never the ladder's to work. Distinct
#: from `answered` (the peer replied) and from `ladder-*` (the ladder tried and
#: failed), because it must not be counted as a dead-letter in the audit rail.
RELEASED = "released"
EXHAUSTED = "ladder-exhausted"
UNRETRYABLE = "ladder-unretryable"


def _now(now: str | datetime | None) -> datetime:
    if isinstance(now, datetime):
        return now if now.tzinfo else now.replace(tzinfo=timezone.utc)
    if now:
        return retry_ladder._parse(now)
    return datetime.now(timezone.utc)


def is_open(row: dict) -> bool:
    """Is the ladder still responsible for this message?

    Four ways a row is closed, and the last is the one that needs saying.
    A row with no `attempts` field predates T-3434; if it is also in a posted
    state, it was DELIVERED before the ladder existed and was never promised
    escalation. The ladder does not adopt it — re-opening every consult this
    project ever delivered would fire a month of nudges at peers about
    conversations that are long finished. (The live ledger held 34 such rows
    when the ladder shipped.) A pre-T-3434 row that is still STORED is a
    different matter: it never reached anyone, which is exactly what the
    ladder is for, so it joins at rung 0.
    """
    state = row.get("state")
    if state == outbox.UNKNOWN:
        return False
    error = row.get("error") or ""
    if error.startswith(ANSWERED) or error.startswith(RELEASED):
        return False
    if row.get("attempts") is None and state in (outbox.INJECTED_NOW,
                                                 outbox.INJECTED_LATER):
        return False
    return True


def latest_rows() -> dict[str, dict]:
    """Latest ledger row per client_msg_id, in ledger order."""
    latest: dict[str, dict] = {}
    for row in outbox._read_ledger():
        cmid = row.get("client_msg_id")
        if cmid:
            latest[cmid] = row
    return latest


def ladder_position(row: dict) -> tuple[int, int | None, str | None]:
    """`(attempts_so_far, next_rung, next_retry_at)`, legacy rows included.

    The row's own `rung` field is backward-looking — the rung its attempt was
    made ON — so the NEXT rung is derived here rather than read off the row.
    That keeps one definition of "where is this message going next" instead of
    two that can disagree.
    """
    attempts = row.get("attempts")
    if attempts is None:
        # Pre-T-3434 row: one attempt was made, at the row's own timestamp.
        scheduled = retry_ladder.next_attempt(1, row.get("ts") or _now(None))
        return 1, (scheduled[0] if scheduled else None), (scheduled[1] if scheduled else None)
    return attempts, retry_ladder.rung_for(attempts), row.get("next_retry_at")


# ── the three escalation collaborators, all injectable ────────────────────────

def answered_conversations(*, reader=inbox.default_reader,
                           agent: str | None = None) -> set[str]:
    """Conversation ids somebody other than us has spoken on, in our inbox.

    A peek: cursor 0, and the inbox cursor is never written. Matching mirrors
    `e2e.is_ack` — the conversation id must match and the message must not be
    our own.
    """
    me = agent or inbox.agent_id()
    topic = inbox.inbox_topic(me)
    answered: set[str] = set()
    for env in reader(topic, 0, inbox.DEFAULT_LIMIT) or []:
        meta = env.get("metadata") or {}
        conversation = meta.get("conversation_id")
        if conversation and meta.get("from_agent") != me:
            answered.add(conversation)
    return answered


def _fw_binary() -> str | None:
    root = outbox._root()
    for candidate in (root / "bin" / "fw", root / ".agentic-framework" / "bin" / "fw"):
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return shutil.which("fw")


def default_operator_notice(msg: dict, rung: int, attempts: int) -> str:
    """Surface one message to the operator via `fw note`.

    `fw note` is the operator's own triage queue (`fw note list`,
    `fw note triage`) and is the operator surface that exists. T-3434 verified
    that observations in `.context/inbox.yaml` have NO Watchtower renderer —
    no blueprint and no template reads that file, and `/gaps` renders
    `concerns.yaml`, a different file. See this task's Updates for the check.
    """
    binary = _fw_binary()
    if not binary:
        return "operator-notice-skipped: no fw binary resolvable"
    text = (f"sidecar consult to {msg.get('to')} unanswered after {attempts} "
            f"attempt(s) on the retry ladder (rung {rung}, conversation "
            f"{msg.get('conversation_id')}, client_msg_id {msg.get('client_msg_id')}). "
            f"Re-posts and inbox nudges have not produced a reply.")
    try:
        proc = subprocess.run([binary, "note", text, "--tag", "sidecar"],
                              capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as exc:
        return f"operator-notice-failed: {exc}"
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip().splitlines()
        return f"operator-notice-failed: {detail[-1][:120] if detail else 'no output'}"
    return "operator-notice-sent"


def default_nudge(msg: dict, rung: int, attempts: int, *, transport) -> str:
    """Post ONE pointer message to the recipient's project-level inbox topic.

    The pointer is short by design: it does not re-send the body (the hub
    already holds it), it tells the recipient something of theirs is unread
    and where to find it. It carries its own `client_msg_id` so receiver-side
    dedupe treats it as a distinct message rather than collapsing it into the
    original, and it is NOT given its own ladder entry.
    """
    pointer = {
        "client_msg_id": f"{msg['client_msg_id']}-nudge-{attempts}",
        "from": msg.get("from"),
        "to": msg.get("to"),
        "hub": msg.get("hub"),
        "conversation_id": msg.get("conversation_id"),
        "body": (f"[nudge] an unread consult from {msg.get('from')} is waiting on "
                 f"conversation {msg.get('conversation_id')} "
                 f"(client_msg_id {msg['client_msg_id']}, {attempts} attempt(s), "
                 f"rung {rung}). Run `fw sidecar inbox` to read it."),
    }
    try:
        transport(pointer)
    except delivery.TransportError as exc:
        return f"nudge-failed: {exc}"
    return "nudge-sent"


# ── the sweep ─────────────────────────────────────────────────────────────────

def sweep(*, now: str | datetime | None = None,
          transport=None, probe=None, reader=inbox.default_reader,
          nudge=default_nudge, operator_notice=default_operator_notice) -> dict:
    """Walk every open row and act on the ones whose rung has come due.

    Returns a report dict: per-verb counts plus one entry per message acted
    on. Never raises on a transport failure — a failed re-post is simply the
    next attempt, and the ladder already knows what to do with it.
    """
    from . import termlink_transport as _tl
    transport = transport if transport is not None else _tl.termlink_transport
    probe = probe if probe is not None else _tl.probe_hub

    now_dt = _now(now)
    rows = {cmid: row for cmid, row in latest_rows().items() if is_open(row)}

    report: dict = {"considered": len(rows), "due": 0, "reposted": 0,
                    "nudged": 0, "operator": 0, "deadlettered": 0,
                    "answered": 0, "actions": []}
    if not rows:
        return report

    answered = answered_conversations(reader=reader)

    for cmid, row in sorted(rows.items()):
        attempts, next_rung, due_at = ladder_position(row)
        posted = row.get("state") in (outbox.INJECTED_NOW, outbox.INJECTED_LATER)

        if attempts >= retry_ladder.MAX_ATTEMPTS or next_rung is None:
            _close(cmid, row, attempts, outbox.UNKNOWN, EXHAUSTED)
            report["deadlettered"] += 1
            report["actions"].append({"client_msg_id": cmid, "verb": "deadletter",
                                      "reason": EXHAUSTED, "attempts": attempts})
            continue

        if not retry_ladder.is_due(due_at, now_dt):
            continue
        report["due"] += 1

        msg = _read_message(cmid)
        conversation = (msg or {}).get("conversation_id") or row.get("conversation_id")
        if posted and conversation and conversation in answered:
            _close(cmid, row, attempts, row.get("state"),
                   f"{ANSWERED}: reply on {conversation}")
            report["answered"] += 1
            report["actions"].append({"client_msg_id": cmid, "verb": ANSWERED,
                                      "conversation_id": conversation})
            continue

        if msg is None:
            # Nothing to re-post and nothing to point at: the durable record
            # is gone, so the ladder cannot own this row any longer.
            _close(cmid, row, attempts, outbox.UNKNOWN,
                   f"{UNRETRYABLE}: message file missing")
            report["deadlettered"] += 1
            report["actions"].append({"client_msg_id": cmid, "verb": "deadletter",
                                      "reason": f"{UNRETRYABLE}: message file missing",
                                      "attempts": attempts})
            continue

        verb = retry_ladder.verb_for(next_rung, posted=posted)
        action = {"client_msg_id": cmid, "verb": verb, "rung": next_rung,
                  "attempts": attempts + 1}

        if verb == retry_ladder.REPOST:
            result = delivery.deliver(cmid, transport, probe, now=now_dt,
                                      attempts=attempts + 1)
            action["state"] = result.state
            action["delivered"] = result.delivered
            if result.reason:
                action["reason"] = result.reason
            report["reposted"] += 1
        elif verb == retry_ladder.NUDGE:
            outcome = nudge(msg, next_rung, attempts + 1, transport=transport)
            action["reason"] = outcome
            _advance(cmid, row, attempts + 1, now_dt, f"escalated:nudge — {outcome}")
            report["nudged"] += 1
        else:  # retry_ladder.OPERATOR
            outcome = operator_notice(msg, next_rung, attempts + 1)
            action["reason"] = outcome
            _advance(cmid, row, attempts + 1, now_dt, f"escalated:operator — {outcome}")
            report["operator"] += 1

        report["actions"].append(action)

    return report


def _read_message(client_msg_id: str) -> dict | None:
    try:
        return delivery.read_message(client_msg_id)
    except (OSError, json.JSONDecodeError):
        return None


def _advance(cmid: str, row: dict, attempts: int, now_dt: datetime,
             error: str) -> None:
    """Record an escalation: same ack state, one rung further along."""
    scheduled = retry_ladder.next_attempt(attempts, now_dt)
    outbox.record_ack(cmid, row.get("target"), row.get("hub"), row.get("state"),
                      deadline=row.get("deadline"), error=error,
                      attempts=attempts,
                      next_retry_at=(scheduled[1] if scheduled else None),
                      rung=retry_ladder.rung_for(attempts - 1))


def _close(cmid: str, row: dict, attempts: int, state: str, error: str) -> None:
    """Record a closing row: the last rung reached, and no next retry."""
    outbox.record_ack(cmid, row.get("target"), row.get("hub"), state,
                      deadline=row.get("deadline"), error=error,
                      attempts=attempts, next_retry_at=None,
                      rung=retry_ladder.rung_for(max(attempts - 1, 0)))
