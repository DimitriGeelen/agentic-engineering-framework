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

from . import identity, inbox

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


#: Env vars termlink consults, in precedence order, to pick a signing identity
#: other than the host default (lib/rail-identity.sh, termlink PL-236).
_IDENTITY_ENV = ("TERMLINK_IDENTITY_FILE", "TERMLINK_AGENT_ID", "TERMLINK_IDENTITY_DIR")


def identity_is_host_shared(*, runner=subprocess.run, timeout: int = 15) -> bool:
    """True when our resolved identity IS the host default, i.e. this project
    has no identity of its own (T-4252).

    DM rails are keyed by that fingerprint, so under the host default every
    project on the machine reads the same rails: draining them marks other
    projects' DMs read (198 lost in the 0909 greenfield run). The host default
    is measured, not hard-coded: the fingerprint termlink reports with the
    identity-selecting env stripped, compared with the one it reports as-is
    (same idea as `lib/rail-identity.sh rail_identity_status`).

    `FW_SIDECAR_IDENTITY_FP` is an explicit key, so it counts as our own.
    Unresolvable returns False: no key means no rails, so there is nothing to
    drain and nothing to protect.
    """
    if os.environ.get("FW_SIDECAR_IDENTITY_FP"):
        return False
    ours = identity_fingerprint(runner=runner, timeout=timeout)
    if not ours:
        return False
    if not any(os.environ.get(k) for k in _IDENTITY_ENV):
        return True
    return _host_fingerprint(runner=runner, timeout=timeout) == ours


def _host_fingerprint(*, runner=subprocess.run, timeout: int = 15) -> str | None:
    """The fingerprint termlink reports with every identity selector stripped:
    the host default, measured rather than hard-coded."""
    saved = {k: os.environ.pop(k) for k in _IDENTITY_ENV if k in os.environ}
    try:
        return identity_fingerprint(runner=runner, timeout=timeout)
    finally:
        os.environ.update(saved)


def legacy_host_fingerprint(*, runner=subprocess.run, timeout: int = 15) -> str | None:
    """The host key this process was moved off by `identity.apply()` (T-4311),
    while the transition is on — else None.

    Peers that DM'd us before the switch wrote to rails keyed by the host
    fingerprint; without this those rails drop out of `rails_for_key()` the
    moment our own key changes and their unread DMs are never seen. Only set
    when apply() did the switching (an operator-exported TERMLINK_IDENTITY_FILE
    is a key they chose, not a transition we caused), and turned off with
    SIDECAR_HOST_DM_TRANSITION=0 once peers address the project key."""
    if os.environ.get("FW_SIDECAR_IDENTITY_FP"):
        return None
    if not os.environ.get(identity.APPLIED_MARKER) or not identity.host_dm_transition():
        return None
    host = _host_fingerprint(runner=runner, timeout=timeout)
    ours = identity_fingerprint(runner=runner, timeout=timeout)
    return host if host and host != ours else None


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


def strict_lister(*, binary: str | None = None, timeout: int = 20) -> list[dict]:
    """`default_lister`, but a listing that did not happen raises
    `inbox.Unreadable` instead of reading as "no rails" (T-4880: the
    session-start mail check must never turn a failed read into silence)."""
    argv = [binary or _binary(), "channel", "list", "--prefix", DM_PREFIX, "--json"]
    try:
        proc = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError) as e:
        raise inbox.Unreadable(f"dm rails: {type(e).__name__}: {e}") from e
    if proc.returncode != 0:
        raise inbox.Unreadable(f"dm rails: termlink channel list exited {proc.returncode}: "
                               f"{(proc.stderr or '').strip()[:200]}")
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError as e:
        raise inbox.Unreadable(f"dm rails: unparseable channel list: {e}") from e
    return (data.get("topics") if isinstance(data, dict) else data) or []


def rails_for_key(key: str | None = None, *, lister=default_lister) -> list[dict]:
    """`dm:*` rails where `key` (default: our own identity fingerprint, plus
    the host key `legacy_host_fingerprint()` names during a T-4311 switch) is
    either side — `dm:<key>:*` or `dm:*:<key>`. Rows pass through from
    `lister()` unchanged. A topic that is not a clean two-party `dm:a:b`
    shape is skipped rather than guessed at."""
    if key is not None:
        keys = {key} if key else set()
    else:
        # T-4311: our own key, plus the host key we moved off while the
        # transition lasts. Cursors live in one store keyed by topic name,
        # so the old rails keep the cursors they already had.
        keys = {k for k in (identity_fingerprint(), legacy_host_fingerprint()) if k}
    if not keys:
        return []
    out = []
    for topic in lister():
        name = topic.get("name") or ""
        if not name.startswith(DM_PREFIX):
            continue
        parts = name[len(DM_PREFIX):].split(":")
        if len(parts) != 2:
            continue
        if keys & set(parts):
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


def shared_summary(*, lister=default_lister, state=None) -> list[dict]:
    """`summary()` rows for the host-keyed rails a T-4311 transition keeps in
    view but that are not on our own key (T-4531). Every project on the host
    reads them, so `fw sidecar inbox` shows them read-only, as T-4252 does for
    a host-shared identity. [] when no transition is on."""
    host = legacy_host_fingerprint()
    if not host:
        return []
    ours = identity_fingerprint()
    rows = summary(host, lister=lister, state=state)
    if ours:
        own = {t.get("name") for t in rails_for_key(ours, lister=lister)}
        rows = [r for r in rows if r["topic"] not in own]
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
    if advance and key is None and identity_is_host_shared():
        # T-4252: never consume rails every project on the host can see.
        return []
    if key is None:
        # T-4531: our own key only. The host key rails_for_key() adds during a
        # T-4311 transition are the host-shared rails every project sees, so
        # they are summaries (shared_summary), never drained.
        key = identity_fingerprint() or ""
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
    own = {key} if key else {k for k in (identity_fingerprint(), legacy_host_fingerprint()) if k}
    rows = []
    for topic in rails_for_key(key, lister=lister):
        name = topic.get("name")
        cursor = topics_state.get(name, {}).get("cursor", 0)
        unread = _unread_count(topic, cursor)
        if unread <= 0:
            continue
        oldest_ts = None
        for env in reader(name, cursor, _STALE_PEEK_LIMIT):
            # T-4880: receipts posted as chat (stage/up_to) and our own posts
            # are not unread mail (TermLink f37f3c3f: 2 "unread" for 43 h on a
            # rail holding only our own smoke posts).
            if not _is_mail(env) or env.get("sender_id") in own:
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


# ---- T-4880: unacted mail, judged per addressee -----------------------------
#
# `stale()` above asks "unread by this identity, past its cursor". On a host
# where projects sign with the shared root key that question has the wrong
# subject: 055's 2026-10-20 report sat on dm:3bba…:d1993c… (3bba = an AEF agent
# key we no longer sign with) and 1023's ~2026-10-15 report on the root key's
# self-DM rail dm:d1993c…:d1993c… (a shared mailbox, posts tagged to_project).
# Neither rail is on our current key, nothing on the session-start path read DM
# rails at all, auto-confirming sidecars posted "delivered" receipts for us, and
# a drain on the shared rail had moved its cursor past the 1023 post. Both
# reached us 8 and 13 days late, by forward (TermLink f37f3c3f, their T-3618).
#
# So the test here is the one TermLink's scripts/check-unacted-mail.sh uses:
# per message, is it addressed to us, and did WE post on that rail after it?
# Cursors, receipts and "delivered" notices say nothing about that.

#: Rails a co-resident project answered on another route can be marked handled
#: here, one `<topic> <offset>` per line (TermLink's escape hatch, same shape).
HANDLED_FILE = ".context/sidecar/dm-handled"

UNACTED_THRESHOLD_HOURS = 24
UNACTED_WINDOW_DAYS = 30
_UNACTED_READ_LIMIT = 1000


def host_shared_address_keys(*, runner=subprocess.run, timeout: int = 15) -> set[str]:
    """T-4892: configured `SIDECAR_DM_ADDRESS_KEYS` entries that ARE the host-shared
    fingerprint. Every project on the machine signed with that key before T-4454, so its
    rails carry other agents' mail too; listing it as ours made `fw sidecar alerts`
    adopt their old mail (832, be.50). Empty when the host key cannot be measured."""
    extra = identity._config("SIDECAR_DM_ADDRESS_KEYS", "")
    keys = {k.strip() for k in extra.split(",") if k.strip()}
    if not keys:
        return set()
    host = _host_fingerprint(runner=runner, timeout=timeout)
    return {host} & keys if host else set()


def address_keys() -> set[str]:
    """Every key a DM addressed to THIS project may be keyed by: our own
    fingerprint, the T-4311 host key while a transition is on, and any older
    agent keys peers still write to (`SIDECAR_DM_ADDRESS_KEYS`, comma list)."""
    keys = {k for k in (identity_fingerprint(), legacy_host_fingerprint()) if k}
    extra = identity._config("SIDECAR_DM_ADDRESS_KEYS", "")
    keys |= {k.strip() for k in extra.split(",") if k.strip()}
    return keys


def _handled(root=None) -> set[tuple[str, int]]:
    from . import receiver
    path = (root or receiver._root()) / HANDLED_FILE
    out = set()
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return out
    for line in lines:
        parts = line.split("#", 1)[0].split()
        if len(parts) >= 2 and parts[1].isdigit():
            out.add((parts[0], int(parts[1])))
    return out


def _is_mail(env: dict) -> bool:
    """Content, not metadata: receipts (by msg_type, or a chat post carrying
    receipt fields `stage`/`up_to`), reactions, edits and notices are not mail."""
    if env.get("msg_type") in META_MSG_TYPES:
        return False
    meta = env.get("metadata") or {}
    if meta.get("stage") or meta.get("up_to"):
        return False
    if meta.get("notice") or meta.get("kind") == "notice":
        return False
    return True


def _party(env: dict) -> str:
    meta = env.get("metadata") or {}
    return str(meta.get("from_project") or meta.get("from") or env.get("sender_id") or "")


def unacted(project: str | None = None, *, keys: set[str] | None = None,
            threshold_hours: float = UNACTED_THRESHOLD_HOURS,
            window_days: float = UNACTED_WINDOW_DAYS,
            lister=default_lister, reader=inbox.default_reader,
            handled: set[tuple[str, int]] | None = None,
            now: datetime | None = None) -> list[dict]:
    """DM posts addressed to `project` that this project has not answered.

    A post is addressed to us when its `to_project` is us, or, with no
    `to_project`, when the rail carries one of our `keys` and the post is not
    our own. It is OPEN until this project posts on the same rail after it.
    Own posts, receipts and notices are never mail and never an answer: an
    auto-confirm "delivered" receipt posted on our behalf reads nothing.
    A to_project naming another project is not ours, even on our own rail.

    Read-only: moves no cursor. Posts younger than `threshold_hours` (still
    fresh) or older than `window_days` are not listed."""
    from . import circuit
    project = project or circuit.project_id()
    keys = address_keys() if keys is None else set(keys)
    handled = _handled() if handled is None else handled
    now_dt = now or datetime.now(timezone.utc)
    now_ms = now_dt.timestamp() * 1000
    rows = []
    for topic in lister():
        name = topic.get("name") or ""
        if not name.startswith(DM_PREFIX):
            continue
        parts = name[len(DM_PREFIX):].split(":")
        on_our_key = len(parts) == 2 and bool(keys & set(parts))
        envs = reader(name, 0, _UNACTED_READ_LIMIT)
        if isinstance(envs, inbox.ReadFailed):
            raise inbox.Unreadable(f"{name}: {getattr(envs, 'reason', 'read failed')}")
        posts = [e for e in envs if _is_mail(e)]
        for i, env in enumerate(posts):
            meta = env.get("metadata") or {}
            to = meta.get("to_project")
            who = _party(env)
            if who == project or (not meta.get("from_project") and env.get("sender_id") in keys
                                  and not to):
                continue  # our own post
            if to:
                if to != project:
                    continue
            elif not on_our_key:
                continue
            offset = env.get("offset")
            if (name, offset) in handled:
                continue
            ts = env.get("ts") or 0
            age_h = (now_ms - ts) / 3.6e6
            if not (threshold_hours <= age_h <= window_days * 24):
                continue
            if any(_party(n) == project for n in posts[i + 1:]):
                continue  # we posted on this rail after it: answered
            body = inbox._decode(env)
            rows.append({
                "route": "dm",
                "id": f"{name}@{offset}",
                "topic": name,
                "offset": offset,
                "from": who or inbox.UNATTRIBUTED,
                "to_project": to,
                "conversation_id": meta.get("conversation_id"),
                "urgent": bool(meta.get("urgent")),
                "age_hours": round(age_h, 1),
                "body": body,
            })
    rows.sort(key=lambda r: -r["age_hours"])
    return rows
