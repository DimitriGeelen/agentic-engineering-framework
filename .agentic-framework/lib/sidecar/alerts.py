"""arc-011 sidecar — session-start mail alerts (T-3856).

`/resume` step 7 ran a project-local `scripts/session-start-alerts.sh` and
skipped silently when it was absent — which it is in every consumer (832,
vendored 1.7.740) and in this repo too. The unseen-mail check never ran in
exactly the places it was built for. This is the shipped replacement for the
mail half (canaries are TermLink's, their T-3327).

Two routes carry peer mail, and both are read here, read-only:
  - the hub consult inbox: `inbox.pending(advance=False)`, through
    `inbox.strict_reader` — a failed read raises instead of returning [],
    which would read as "no mail" (the very silence this exists to end);
  - receiver-stored messages awaiting hand-over, minus `seen.withheld` (T-3872),
    so this lists exactly what the prompt hook would show.

A third, T-4880: DM posts addressed to this project that it has not answered
(`dm.unacted`). 055's and 1023's reports sat on DM rails for 8 and 13 days
because nothing here read DM rails. Unlike the two routes above these are not
"unseen" but "unacted": they stay listed until we post on that rail, or the
post is marked handled in `dm.HANDLED_FILE`; --mark-seen does not hide them.

Any failure to read raises `Unreadable`; the CLI turns it into
`NOT CHECKED: <reason>` (exit 3). Never an empty answer for a failed read.
"""

from __future__ import annotations

from . import dm, inbox, receiver, seen

DEFAULT_LIMIT = 10


# T-4452: one strict reader, defined beside the lenient one in inbox.py.
# Re-exported under the names callers already use.
Unreadable = inbox.Unreadable
strict_reader = inbox.strict_reader


def _first_line(body) -> str:
    for line in str(body or "").splitlines():
        if line.strip():
            return line.strip()[:160]
    return ""


def collect(limit: int = DEFAULT_LIMIT, *, reader=strict_reader,
            dm_unacted=None) -> list[dict]:
    """Unseen peer mail on both routes, plus unacted DM mail (T-4880), one
    row per message (by base id). `dm_unacted` is a no-arg callable returning
    `dm.unacted()` rows (default: the live hub, strict)."""
    rows: list[dict] = []
    keys_seen: set[str] = set()

    def add(mid: str, msg: dict, route: str) -> None:
        keys = seen.keys_for(mid, msg)
        if keys & keys_seen:
            return
        keys_seen.update(keys)
        rows.append({
            "route": route,
            "id": mid,
            "from": inbox.sender_label(msg),
            "conversation_id": msg.get("conversation_id"),
            "urgent": bool(msg.get("urgent")),
            "first_line": _first_line(msg.get("body")),
            "_msg": msg,
        })

    try:
        consults = inbox.pending(advance=False, reader=reader)
    except Unreadable:
        raise
    except Exception as e:
        raise Unreadable(f"hub inbox: {type(e).__name__}: {e}") from e
    for m in consults:
        add(str(m.get("client_msg_id") or f"@{m.get('offset')}"), m, "hub")

    try:
        waiting = receiver.awaiting_handover()
        held = seen.withheld(waiting)
        for mid in waiting:
            if mid in held:
                continue
            m = receiver.read_message(mid)
            if m:
                add(mid, m, "receiver")
    except Exception as e:
        raise Unreadable(f"receiver store: {type(e).__name__}: {e}") from e

    if dm_unacted is None:
        def dm_unacted():
            return dm.unacted(lister=dm.strict_lister, reader=reader)
    try:
        dm_rows = dm_unacted()
    except Unreadable:
        raise
    except Exception as e:
        raise Unreadable(f"dm rails: {type(e).__name__}: {e}") from e
    for r in dm_rows:
        rows.append({
            "route": "dm",
            "id": r["id"],
            "from": r["from"],
            "conversation_id": r.get("conversation_id"),
            "urgent": r.get("urgent", False),
            "first_line": _first_line(r.get("body")),
            "age_hours": r.get("age_hours"),
            "_unacted": True,
        })

    rows.sort(key=lambda r: not r["urgent"])
    return rows[:limit] if limit and limit > 0 else rows


def mark_seen(rows: list[dict]) -> None:
    """Record the listed messages as shown, so the prompt hook and a later
    `alerts` call do not repeat them."""
    seen.mark_shown([(r["id"], r.get("_msg")) for r in rows if not r.get("_unacted")],
                    by="alerts")
