"""arc-011 sidecar — session-start mail alerts (T-3856).

`/resume` step 7 ran a project-local `scripts/session-start-alerts.sh` and
skipped silently when it was absent — which it is in every consumer (832,
vendored 1.7.740) and in this repo too. The unseen-mail check never ran in
exactly the places it was built for. This is the shipped replacement for the
mail half (canaries are TermLink's, their T-3327).

Two routes carry peer mail, and both are read here, read-only:
  - the hub consult inbox: `inbox.pending(advance=False)`, through a STRICT
    reader — `inbox.default_reader` returns [] on any failure, which would read
    as "no mail" (the very silence this exists to end);
  - receiver-stored messages awaiting hand-over, minus `seen.withheld` (T-3872),
    so this lists exactly what the prompt hook would show.

Any failure to read raises `Unreadable`; the CLI turns it into
`NOT CHECKED: <reason>` (exit 3). Never an empty answer for a failed read.
"""

from __future__ import annotations

import json
import shutil
import subprocess

from . import inbox, receiver, seen

DEFAULT_LIMIT = 10


class Unreadable(RuntimeError):
    """A mail route could not be read; the answer is unknown, not empty."""


def strict_reader(topic: str, cursor: int, limit: int = inbox.DEFAULT_LIMIT,
                  *, timeout: int = 15) -> list[dict]:
    binary = inbox._binary()
    if not (shutil.which(binary) or binary.startswith("/")):
        raise Unreadable(f"termlink binary not found ({binary})")
    argv = [binary, "channel", "subscribe", topic, "--json",
            "--cursor", str(cursor), "--limit", str(limit)]
    try:
        proc = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError) as e:
        raise Unreadable(f"reading {topic}: {type(e).__name__}: {e}") from e
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip().splitlines()
        # A topic that does not exist yet holds no mail; anything else is unknown.
        if any(s in l.lower() for l in err
               for s in ("unknown topic", "no such topic", "topic not found")):
            return []
        raise Unreadable(f"reading {topic}: rc={proc.returncode} {err[-1] if err else ''}".strip())
    out = []
    for line in (proc.stdout or "").splitlines():
        line = line.strip()
        if line:
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return out


def _first_line(body) -> str:
    for line in str(body or "").splitlines():
        if line.strip():
            return line.strip()[:160]
    return ""


def collect(limit: int = DEFAULT_LIMIT, *, reader=strict_reader) -> list[dict]:
    """Unseen peer mail on both routes, one row per message (by base id)."""
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

    rows.sort(key=lambda r: not r["urgent"])
    return rows[:limit] if limit and limit > 0 else rows


def mark_seen(rows: list[dict]) -> None:
    """Record the listed messages as shown, so the prompt hook and a later
    `alerts` call do not repeat them."""
    seen.mark_shown([(r["id"], r.get("_msg")) for r in rows], by="alerts")
