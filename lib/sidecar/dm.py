"""arc-011 sidecar — DM rail discovery and draining (T-3442).

Origin: 832's substantive answer on EWCR clause 2 sat unread for weeks on
`dm:3bba15e681b3a078:d1993c2c3ec44c94` — a rail addressed to our own
identity — because two things were both structurally blind to it:
`termlink agent search` does not scan `dm:*` topics (theirs, T-3442 AC3),
and nothing on our side drained a DM rail at all (ours, this module).

**Why "our key" is a TermLink identity fingerprint, not a circuit id.**
`inbox:<circuit-id>` topics (T-3433, `lib/sidecar/circuit.py`) are ours to
name — the framework picked that address on purpose, scoped to a project or
an agent. A `dm:<a>:<b>` rail's two segments are TermLink's OWN convention
(`termlink agent contact` / `channel dm`), keyed by the session identity
fingerprint `termlink whoami` reports — machine-wide (T-3405: shared across
every process on a host), not project- or agent-scoped. That is inherent to
how TermLink names DM rails; this module reads that convention, it does not
choose it.

**Why cursors live in the SAME `inbox-state.json` `topics` map.** A DM
rail's read position is the same kind of fact an `inbox:`/`sidecar:` topic
cursor already is — "how far have we drained this topic" — so it is stored
identically, keyed by the rail's topic name, rather than inventing a second
state file (ground truth for T-3442, and consistent with `inbox.py`'s own
"one cursor per topic" shape).

**Why `summary()` and `stale()` are allowed to call the hub, unlike
`status.snapshot()`.** `lib/sidecar/status.py`'s one design rule is that it
reads only our own durable state and never asks the hub — that guarantee is
about not letting a hub's self-reported delivery status move ack-ledger
numbers we already trust. Listing which `dm:*` topics exist and how many
posts they hold is a different question with no durable answer of its own:
the hub is the only place that fact lives. `sidecar_cli.py`'s `cmd_status`
therefore queries this module SEPARATELY from `status_mod.snapshot()` and
merges the result, so `snapshot()` itself stays hub-free exactly as
documented.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from datetime import datetime, timedelta, timezone

from . import inbox

DM_PREFIX = "dm:"

#: msg_types TermLink itself treats as channel metadata rather than content
#: (same set `termlink channel unread --help` documents excluding). A DM
#: rail's offset 0 is almost always a `topic_metadata` "created by" banner;
#: reactions/receipts/edits/redactions can appear anywhere after that.
META_MSG_TYPES = {"receipt", "reaction", "redaction", "edit", "topic_metadata"}

#: How many envelopes to peek from a rail's cursor when hunting for the
#: oldest UNREAD CONTENT post's timestamp (`stale()`). Bounded rather than
#: unlimited so a rail with a long run of reactions/receipts right after the
#: cursor cannot turn one doctor run into an unbounded drain.
_STALE_PEEK_LIMIT = 20


def _binary() -> str:
    return shutil.which("termlink") or "termlink"


def identity_fingerprint(*, runner=subprocess.run, timeout: int = 15) -> str | None:
    """This host's TermLink identity fingerprint — the key DM rails are
    addressed with. `FW_SIDECAR_IDENTITY_FP` overrides for tests and for a
    host where the live call is unavailable. Returns None (never raises) on
    any failure — callers treat "no key" as "no rails", not an error, the
    same degrade-quietly shape `status._circuit_or_none` uses.
    """
    env = os.environ.get("FW_SIDECAR_IDENTITY_FP")
    if env:
        return env
    try:
        proc = runner([_binary(), "whoami", "--json"], capture_output=True,
                      text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0:
        return None
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        return None
    return (data.get("session") or {}).get("identity_fingerprint")


def default_lister(*, binary: str | None = None, timeout: int = 20) -> list[dict]:
    """Every `dm:*` topic on the hub: `{name, count, latest_offset, ...}`
    straight from `termlink channel list --prefix dm: --json` — one call
    covers every rail, so this stays cheap regardless of how many DM rails
    exist on the hub."""
    argv = [binary or _binary(), "channel", "list", "--prefix", DM_PREFIX, "--json"]
    try:
        proc = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return []
    if proc.returncode != 0:
        return []
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        return []
    return data.get("topics") or []


def rails_for_key(key: str | None = None, *, lister=default_lister) -> list[dict]:
    """`dm:*` rails where `key` (default: our own identity fingerprint) is
    either side — `dm:<key>:*` or `dm:*:<key>`. Rows pass through from
    `lister()` unchanged. A topic that is not a clean two-party `dm:a:b`
    shape is skipped rather than guessed at."""
    key = key if key is not None else identity_fingerprint()
    if not key:
        return []
    out = []
    for topic in lister():
        name = topic.get("name") or ""
        if not name.startswith(DM_PREFIX):
            continue
        parts = name[len(DM_PREFIX):].split(":")
        if len(parts) != 2:
            continue
        if key in parts:
            out.append(topic)
    return out


def _unread_count(topic: dict, cursor: int) -> int:
    """Posts newer than `cursor`, bounded by how many the hub actually still
    holds (`count`) — a retention-truncated rail can have `latest_offset`
    far ahead of `count` when old offsets were evicted, and the truth is
    never more than what is still there."""
    latest = topic.get("latest_offset")
    count = topic.get("count") or 0
    if not isinstance(latest, int):
        return 0
    return max(0, min(count, latest + 1 - cursor))


def summary(key: str | None = None, *, lister=default_lister, state=None) -> list[dict]:
    """Every rail addressed to `key`, with post count and unread-vs-cursor —
    the T-3442 AC1 peek shape for `fw sidecar inbox --peek` / `fw sidecar
    status`. One hub call total (via `lister`); does not drain content and
    does not move any cursor."""
    state = state if state is not None else inbox.load_state()
    topics_state = state.get("topics", {})
    rows = []
    for topic in rails_for_key(key, lister=lister):
        name = topic.get("name")
        cursor = topics_state.get(name, {}).get("cursor", 0)
        rows.append({
            "topic": name,
            "count": topic.get("count") or 0,
            "latest_offset": topic.get("latest_offset"),
            "cursor": cursor,
            "unread": _unread_count(topic, cursor),
        })
    return rows


def pending(key: str | None = None, *, reader=inbox.default_reader,
            lister=default_lister, advance: bool = True,
            limit: int = inbox.DEFAULT_LIMIT) -> list[dict]:
    """Unread CONTENT posts on every rail addressed to `key`. Drains via
    `reader` (T-3406's `inbox.default_reader`, reused rather than
    reimplemented) and stores the cursor in the SAME `topics` map
    `inbox.pending` uses, keyed by the rail's topic name — a DM rail's
    cursor sits alongside an `inbox:`/`sidecar:` topic's, not in a second
    store.

    Meta envelopes (topic_metadata/receipt/reaction/redaction/edit) still
    advance the cursor past themselves — they were genuinely read — but are
    excluded from the returned list, matching what `termlink channel
    unread` itself counts as a post.
    """
    state = inbox.load_state()
    fresh = []
    for topic in rails_for_key(key, lister=lister):
        name = topic.get("name")
        entry = state["topics"].setdefault(name, {"cursor": 0})
        highest = entry.get("cursor", 0)
        for env in reader(name, highest, limit):
            offset = env.get("offset")
            if isinstance(offset, int):
                highest = max(highest, offset + 1)
            if env.get("msg_type") in META_MSG_TYPES:
                continue
            meta = env.get("metadata") or {}
            fresh.append({
                "offset": offset,
                "topic": name,
                "from": env.get("sender_id"),
                "conversation_id": meta.get("conversation_id"),
                "body": inbox._decode(env),
                "ts": env.get("ts"),
            })
        if advance:
            entry["cursor"] = highest
    if advance:
        inbox.save_state(state)
    return fresh


def stale(min_age_hours: float = 24, *, key: str | None = None,
          lister=default_lister, reader=inbox.default_reader,
          now: datetime | None = None) -> list[dict]:
    """Rails with an unread content post older than `min_age_hours` — the
    T-3442 AC2 WARN shape for `fw doctor` / `fw audit`. Peeks the oldest
    unread envelope per rail (bounded `reader` call, `_STALE_PEEK_LIMIT`)
    purely to read its timestamp; moves no cursor.
    """
    now_dt = now or datetime.now(timezone.utc)
    threshold = now_dt - timedelta(hours=min_age_hours)
    state = inbox.load_state()
    topics_state = state.get("topics", {})
    rows = []
    for topic in rails_for_key(key, lister=lister):
        name = topic.get("name")
        cursor = topics_state.get(name, {}).get("cursor", 0)
        unread = _unread_count(topic, cursor)
        if unread <= 0:
            continue
        oldest_ts = None
        for env in reader(name, cursor, _STALE_PEEK_LIMIT):
            if env.get("msg_type") in META_MSG_TYPES:
                continue
            ts_ms = env.get("ts")
            if isinstance(ts_ms, (int, float)):
                oldest_ts = datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc)
            break
        if oldest_ts is None or oldest_ts > threshold:
            continue
        age_hours = (now_dt - oldest_ts).total_seconds() / 3600
        rows.append({
            "topic": name,
            "unread": unread,
            "oldest_unread_ts": oldest_ts.isoformat(),
            "age_hours": round(age_hours, 1),
        })
    return rows
