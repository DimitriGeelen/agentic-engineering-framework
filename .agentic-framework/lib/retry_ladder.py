"""The universal message retry ladder (D-600, T-3434).

One schedule, shared by every framework message kind — sidecar consults,
pickups, learning publishes, dispatch results. This module is **pure**: no
I/O, no clock of its own, no knowledge of any transport. It answers two
questions and nothing else:

    next_attempt(attempts, last_at) -> (rung, due_at) | None
        when is the next attempt due, and which rung is it on?
        None means the ladder is exhausted — the caller dead-letters.

    verb_for(rung, posted=...) -> "repost" | "escalate:nudge"
                                | "escalate:operator" | "deadletter"
        what should the caller DO on that rung?

**The schedule.** Sixteen attempts across eight rungs, doubling out from a
minute to a month::

    2 x 1min   2 x 5min   2 x 15min   2 x 1h
    2 x 4h     2 x 1d     2 x 1w      2 x 1mo

Total wall-clock span ≈ 76 days (6,604,920s). The first attempt is made in-process by
the producer (it is attempt 1); every later attempt is made by whatever
periodic sweep drives the ladder — for the sidecar, the 5-minute
`sidecar-sweep-5m` cron. The first two rungs are therefore finer-grained
than the sweep that drives them; that is deliberate and harmless, a rung
that comes due between sweeps simply fires on the next sweep.

**Two failure classes, one schedule, different verbs** (D-600). A message
that never reached the hub is RE-POSTED — the recipient has nothing, so
sending again is the only move. A message the hub holds but nobody read is
ESCALATED, because re-posting the same body into the same unread topic adds
noise, not reach: at the 15-minute rung we nudge the recipient's
project-level inbox, at the 1-day rung we surface to the operator, and after
the last rung we dead-letter. `posted=` selects the class; `verb_for(rung)`
with no class argument returns the escalation mapping, which is the one the
acceptance criterion names.

**Why the receiver MUST dedupe.** This ladder deliberately outlives
TermLink's hub-side dedupe window, measured at ~5 minutes (T-3405, where a
re-post at +15m39s appended a duplicate). From the 15-minute rung onward the
hub will happily accept a re-post of an id it has already seen. We told
TermLink we diverge from their "the sender gives up inside the TTL"
assumption knowingly. The consequence is not optional: **every consumer of
this ladder must dedupe on the message id at the receiving end.** A producer
that adopts the ladder without a receiver-side seen-set has not adopted the
ladder, it has adopted a duplicate generator.

**URGENT is out of scope.** `urgent` is accepted as a parameter and raises
NotImplementedError. D-600 rules that urgent *compresses* the ladder, and
rules equally plainly that the compression is designed in a separate
conversation. The parameter exists so callers can thread the flag through
today and get a loud, locatable failure instead of a silent normal-priority
send. See `docs/reports/T-3434-retry-ladder.md` §What urgent will change.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

#: (attempts_on_this_rung, seconds_between_attempts), coarsening left to right.
LADDER: list[tuple[int, int]] = [
    (2, 60),        # 2 x 1 min
    (2, 300),       # 2 x 5 min
    (2, 900),       # 2 x 15 min
    (2, 3600),      # 2 x 1 h
    (2, 14400),     # 2 x 4 h
    (2, 86400),     # 2 x 1 d
    (2, 604800),    # 2 x 1 w
    (2, 2592000),   # 2 x 30 d
]

#: Total attempts the ladder allows, first (in-process) attempt included.
MAX_ATTEMPTS = sum(count for count, _ in LADDER)

#: Rung index at which escalation replaces re-posting for a posted message.
NUDGE_RUNG = 2       # the 15-minute rung
#: Rung index at which the operator is surfaced.
OPERATOR_RUNG = 5    # the 1-day rung

REPOST = "repost"
NUDGE = "escalate:nudge"
OPERATOR = "escalate:operator"
DEADLETTER = "deadletter"

_URGENT_MSG = (
    "urgent ladder compression is out of scope for T-3434 — D-600 rules that "
    "URGENT compresses the ladder and that the compression is designed in a "
    "separate conversation. See docs/reports/T-3434-retry-ladder.md "
    "§What urgent will change (pointer only)."
)


def _require_not_urgent(urgent: bool) -> None:
    if urgent:
        raise NotImplementedError(_URGENT_MSG)


def rung_for(attempts: int, *, urgent: bool = False) -> int | None:
    """Which rung the NEXT attempt sits on, given `attempts` already made.

    `attempts` counts attempts already made, so the next attempt is number
    `attempts + 1` and its zero-based index is `attempts`. Returns None once
    the ladder is exhausted.
    """
    _require_not_urgent(urgent)
    if attempts < 0:
        raise ValueError(f"attempts must be >= 0, got {attempts}")
    index = attempts
    for rung, (count, _seconds) in enumerate(LADDER):
        if index < count:
            return rung
        index -= count
    return None


def delay_for(rung: int) -> int:
    """Seconds between attempts on `rung`."""
    return LADDER[rung][1]


def _parse(value: str | datetime) -> datetime:
    dt = value if isinstance(value, datetime) else datetime.fromisoformat(value)
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def next_attempt(attempts: int, last_at: str | datetime,
                 *, urgent: bool = False) -> tuple[int, str] | None:
    """When the next attempt is due, and on which rung.

    Returns `(rung, due_at_iso)`, or None when the ladder is exhausted and
    the caller should dead-letter. `last_at` is when the previous attempt
    was made (ISO-8601 string or datetime); a naive value is read as UTC.
    """
    rung = rung_for(attempts, urgent=urgent)
    if rung is None:
        return None
    due = _parse(last_at) + timedelta(seconds=delay_for(rung))
    return rung, due.isoformat()


def is_due(next_retry_at: str | datetime | None,
           now: str | datetime | None = None) -> bool:
    """Has `next_retry_at` arrived? A missing due time is treated as due."""
    if not next_retry_at:
        return True
    now_dt = _parse(now) if now else datetime.now(timezone.utc)
    return now_dt >= _parse(next_retry_at)


def verb_for(rung: int | None, *, posted: bool = True,
             urgent: bool = False) -> str:
    """What to do on `rung`. `rung=None` (exhausted) is always deadletter.

    `posted=True` (the default, and the mapping the acceptance criterion
    names) is the escalation class: a message the hub holds that nobody
    read. `posted=False` is the re-post class: a message that never reached
    the hub at all, where re-posting stays the right move on every rung
    because the recipient has nothing to be nudged about.
    """
    _require_not_urgent(urgent)
    if rung is None or rung < 0 or rung >= len(LADDER):
        return DEADLETTER
    if not posted:
        return REPOST
    if rung >= OPERATOR_RUNG:
        return OPERATOR
    if rung >= NUDGE_RUNG:
        return NUDGE
    return REPOST


def describe() -> str:
    """One line per rung. For `--help` text and reports, not for parsing."""
    lines = []
    attempts = 0
    for rung, (count, seconds) in enumerate(LADDER):
        lines.append(
            f"rung {rung}: {count} x {seconds}s  "
            f"(attempts {attempts + 1}-{attempts + count})  "
            f"posted -> {verb_for(rung)}   un-posted -> {verb_for(rung, posted=False)}")
        attempts += count
    lines.append(f"exhausted after attempt {attempts} -> {DEADLETTER}")
    return "\n".join(lines)
