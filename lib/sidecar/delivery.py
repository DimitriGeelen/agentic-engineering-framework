"""arc-011 sidecar — uniform delivery transport for the outbox.

T-3404 (T-3397 Amendment 5, slice 2). Slice 1 (T-3402, `outbox.py`) made
messages durable; this module delivers them.

Two things this module is deliberately built around, both from the design
doc rather than invented here:

1. **One path, not two.** Amendment 5 settles delivery as cross-host-capable
   by construction, with same-host as the *degenerate* case (`hub: None`).
   So there is no same-host branch: `hub` is data flowing through one code
   path, and the per-hub precondition probe runs for the local hub too.

2. **Failure is loud and non-terminal.** Amendment 4: TermLink supplies no
   retry-on-blip, and cross-hub posts bypass its offline queue entirely —
   a post either succeeds or fails loudly, with no free retry underneath.
   So a failed delivery here records the attempt and leaves the message in
   `STORED`, which is the one non-terminal state; retry is caller-owned and
   is idempotent because the `client_msg_id` travels with the retry. The
   failure row carries a deadline, so a message nobody retries is swept to
   `UNKNOWN` by `outbox.resolve_expired` rather than sitting stuck forever
   wearing a success label.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from .. import retry_ladder
from . import outbox

DEFAULT_DEADLINE_SECONDS = 30


class TransportError(Exception):
    """A transport failed to post. Raised by the transport, never swallowed."""


@dataclass(frozen=True)
class ProbeResult:
    """Outcome of a hub's capability / version-floor precondition check."""

    ok: bool
    reason: str = ""


@dataclass(frozen=True)
class DeliveryResult:
    client_msg_id: str
    state: str
    delivered: bool
    reason: str = ""


def _message_path(client_msg_id: str):
    return outbox._outbox_dir() / f"{client_msg_id}.json"


def _flag_path(client_msg_id: str):
    return outbox._outbox_dir() / f"{client_msg_id}.flag"


def read_message(client_msg_id: str) -> dict:
    with open(_message_path(client_msg_id), encoding="utf-8") as fh:
        return json.load(fh)


def _deadline_iso(now: datetime | None, seconds: int) -> str:
    base = now or datetime.now(timezone.utc)
    return (base + timedelta(seconds=seconds)).isoformat()


def always_ok_probe(hub: str | None) -> ProbeResult:
    """Default probe. Accepts every hub.

    A real probe checks the hub's advertised capabilities and version floor
    before it is treated as a valid send target (Amendment 5's cross-host
    extension, which that amendment makes an acceptance gate rather than a
    follow-up). This default exists so the transport seam is testable and so
    the caller must pass a real probe deliberately — it is NOT the probe to
    ship against a live fleet.
    """
    return ProbeResult(ok=True)


def deliver(client_msg_id: str, transport, probe=always_ok_probe, *,
            fast_path: bool = True, now: datetime | None = None,
            deadline_seconds: int = DEFAULT_DEADLINE_SECONDS,
            attempts: int = 1) -> DeliveryResult:
    """Deliver one stored message. Returns the resulting DeliveryResult.

    `transport(message: dict) -> Any` posts the message and raises
    TransportError on failure. `probe(hub) -> ProbeResult` gates the hub.
    `fast_path` distinguishes the two terminal success states Amendment 5
    defines: INJECTED_NOW (fired before the caller returns) from
    INJECTED_LATER (a later sweep delivered it).

    `attempts` is this delivery's position on the universal retry ladder
    (T-3434) — 1 for the producer's own in-process attempt, and whatever the
    sweep passes for a retry. Every row written here carries `attempts`, the
    `rung` this attempt was made on, and the `next_retry_at` the following one
    is due at, so the sweep never has to reconstruct a ladder position from
    timestamps. A successful
    delivery is scheduled too: `INJECTED_*` means the hub took it, not that
    anyone read it, and the unread case is the second failure class D-600
    escalates rather than abandons.
    """
    msg = read_message(client_msg_id)
    hub = msg.get("hub")
    target = msg.get("to")
    deadline = _deadline_iso(now, deadline_seconds)
    base = (now or datetime.now(timezone.utc)).isoformat()
    # `rung` names the rung THIS attempt was made on; `next_retry_at` is when
    # the following attempt comes due. Keeping the two on different clocks —
    # one backward-looking, one forward — is what lets a forensics reader
    # answer "where was it, and when is it next" from a single row.
    rung = retry_ladder.rung_for(attempts - 1)
    scheduled = retry_ladder.next_attempt(attempts, base)
    next_retry_at = scheduled[1] if scheduled else None

    def _record(state: str, error: str | None = None) -> None:
        outbox.record_ack(client_msg_id, target, hub, state, deadline=deadline,
                          error=error, attempts=attempts,
                          next_retry_at=next_retry_at, rung=rung)

    verdict = probe(hub)
    if not verdict.ok:
        reason = f"hub-refused: {verdict.reason}"
        _record(outbox.STORED, reason)
        return DeliveryResult(client_msg_id, outbox.STORED, False, reason)

    try:
        transport(msg)
    except TransportError as exc:
        reason = f"transport-failed: {exc}"
        _record(outbox.STORED, reason)
        return DeliveryResult(client_msg_id, outbox.STORED, False, reason)

    state = outbox.INJECTED_NOW if fast_path else outbox.INJECTED_LATER
    _record(state)
    _consume_flag(client_msg_id)
    return DeliveryResult(client_msg_id, state, True)


def _consume_flag(client_msg_id: str) -> None:
    """Drop the dirty-bit so the message leaves `list_pending`.

    The message file itself is kept: it is the durable record of what was
    sent, and the flag alone is what marks work outstanding.
    """
    try:
        os.unlink(_flag_path(client_msg_id))
    except FileNotFoundError:
        pass
