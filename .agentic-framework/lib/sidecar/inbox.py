"""arc-011 sidecar — inbox: consults addressed to this agent.

T-3406, slice 4. Slices 1-3 could send; nothing could read. This is the
receiving half, and the two decisions in it are both forced by measurements
from earlier slices rather than chosen freely:

**Why we keep our own cursor instead of `channel subscribe --resume`.**
TermLink's persisted cursor lives in `~/.termlink/cursors.json` keyed by
`(topic, identity)`, and the identity is machine-wide — measured in T-3405,
where this project and 832-Workflow-designer both post under fingerprint
`d1993c2c3ec44c94`. Two AEF projects on one host would therefore share and
clobber one cursor. Ours is per-project state under `.context/sidecar/`.

**Why we dedupe on `client_msg_id` here at all.** The hub's own dedupe is
TTL-bounded — measured at ~5 minutes in T-3405, where a re-post at +15m39s
appended a duplicate. So a sender retrying on any deadline longer than that
TTL delivers twice, and only the receiver can collapse it. Slice 3 put the
id into envelope metadata precisely so this side has something to key on.
This does NOT decide OBS-447's open question (bound the retry window vs.
receiver-side dedupe) — receiver-side dedupe is required under either
answer, so building it prejudges nothing.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
from datetime import datetime, timezone

from . import circuit, outbox

DEFAULT_LIMIT = 100

#: How many client_msg_ids to remember per topic for duplicate suppression.
#: Bounded so the state file cannot grow without limit; generous relative to
#: the hub's own 5-minute window, which is what it exists to outlast.
SEEN_CAP = 500


def agent_id() -> str:
    """This agent's addressable name.

    NOT the TermLink identity fingerprint: that is machine-wide (T-3405),
    so it names a host, not an agent, and cannot route a consult.
    """
    return circuit.agent_name()


def inbox_topic(agent: str | None = None) -> str:
    """The `inbox:<circuit-id>` topic a consult for `agent` lands on (T-3433).

    With no argument this is OUR exact circuit — which truncates to the
    durable role address when this session has no agent distinct from the
    project, and that is the right answer rather than a degraded one. With an
    argument it is whatever that name resolves to (circuit.resolve_address).
    """
    if agent is None:
        return circuit.topic_for_circuit(circuit.circuit_id("agent"))
    return circuit.topic_for_name(agent)


def legacy_topics(agent: str | None = None) -> list[str]:
    """The `sidecar:` topics this address used to be, kept as a READ alias for
    one release (T-3433). Senders never write them; `pending()` drains them so
    a consult posted by a peer that has not yet switched still arrives."""
    return [circuit.legacy_topic_for(agent or agent_id())]


def v9_topics(agent: str | None = None) -> list[str]:
    """The V9 spelling of this agent's inbox topic (T-3479).

    READ-SIDE ONLY. Senders still write the T-3433 form; this exists so that a
    peer which has already switched to V9 is heard before we change anything
    they can observe. The write-side cut is a later slice and is gated on
    telling 832, 010-termlink and 1409-sprind first.
    """
    cid = circuit.circuit_id("agent") if agent is None \
        else circuit.resolve_address(agent)
    return [circuit.v9_topic_for_circuit(cid)]


def read_topics(agent: str | None = None) -> list[str]:
    """Every topic a reader for `agent` must consult. THE one definition.

    T-3462 (OBS-529): this list used to be written out at each call site, and
    the two copies drifted the moment the T-3433 transition widened one of
    them. `pending()` was widened to drain circuit + legacy; `retry.
    answered_conversations()` was not, and kept peeking the circuit topic
    alone.

    The consequence was not a missing message — `pending()` still surfaced
    everything — it was that the SWEEP could not see a reply. A peer answering
    on the legacy rail left the ack-ledger row open, so every five minutes the
    retry ladder re-posted, nudged, and eventually fired an operator notice
    for a conversation that had been answered days earlier. Measured
    2026-09-25: the circuit topic held 0 foreign conversations and the legacy
    topic held 8, including all three that had climbed to rung 5.

    So: one function, called by both. A future address change widens this and
    every reader follows. Adding a topic at a call site is the bug.

    T-3479 is that future address change, and this is the whole of its read
    half: the V9 topic joins the list here, and `pending()` plus
    `retry.answered_conversations()` both follow without being touched. That
    the widening is a one-line change in one place is the property T-3462 built
    this function to have, now collected.
    """
    return [inbox_topic(agent)] + v9_topics(agent) + legacy_topics(agent)


def _state_path():
    path = outbox._root() / ".context" / "sidecar" / "inbox-state.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def load_state() -> dict:
    path = _state_path()
    if not path.exists():
        return {"topics": {}}
    try:
        with open(path, encoding="utf-8") as fh:
            state = json.load(fh)
    except (json.JSONDecodeError, OSError):
        return {"topics": {}}
    state.setdefault("topics", {})
    return state


def save_state(state: dict) -> None:
    path = _state_path()
    tmp = path.with_suffix(".json.tmp")
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(state, fh, indent=2)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, path)


def _binary() -> str:
    return shutil.which("termlink") or "termlink"


def topic_present(topic: str, *, runner=subprocess.run, binary: str | None = None,
                  timeout: int = 15, hub: str | None = None) -> tuple[bool | None, str]:
    """(present, reason) for one hub topic (T-3803).

    True/False when the hub answered, None when it could not be asked. The
    distinction matters: `default_reader` turns the hub's "unknown topic"
    refusal into an empty list, so a missing inbox and an empty one used to
    read the same — `fw sidecar status` printed 0 either way.
    """
    argv = [binary or _binary(), "channel", "list", "--prefix", topic, "--json"]
    if hub:  # T-3899: ask the RECIPIENT's hub, not ours
        argv += ["--hub", hub]
    try:
        proc = runner(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError) as e:
        return None, f"termlink channel list failed: {e}"
    if proc.returncode != 0:
        return None, ((proc.stderr or proc.stdout or "").strip()[:200]
                      or f"termlink channel list exited {proc.returncode}")
    try:
        names = {t.get("name") for t in json.loads(proc.stdout or "{}").get("topics", [])}
    except (json.JSONDecodeError, AttributeError):
        return None, "termlink channel list returned unparseable output"
    if topic in names:
        return True, "present"
    return False, f"topic {topic} does not exist on the hub"


def ensure_topic(agent: str | None = None, *, runner=subprocess.run,
                 binary: str | None = None, timeout: int = 15) -> dict:
    """Create this agent's own inbox topic if the hub does not have it (T-3803).

    Until this existed nothing on the RECEIVING side ever created the topic:
    only a sender's `channel post --ensure-topic` did. A fresh project's
    `fw sidecar inbox` therefore read "unknown topic" (swallowed to empty)
    until some peer happened to write first — reported on ring20 .121/.122.

    Idempotent: a present topic is left alone (its retention untouched — the
    hub refuses a re-create that would change it). Returns
    `{topic, ok, action, reason}`; `action` is one of exists/created/failed.
    """
    topic = inbox_topic(agent)
    present, reason = topic_present(topic, runner=runner, binary=binary, timeout=timeout)
    if present:
        return {"topic": topic, "ok": True, "action": "exists", "reason": reason}
    argv = [binary or _binary(), "channel", "create", topic, "--json"]
    try:
        proc = runner(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError) as e:
        return {"topic": topic, "ok": False, "action": "failed",
                "reason": f"termlink channel create failed: {e}"}
    out = (proc.stderr or "") + (proc.stdout or "")
    if proc.returncode == 0:
        return {"topic": topic, "ok": True, "action": "created", "reason": "created"}
    if "already exists" in out:  # a peer created it between list and create
        return {"topic": topic, "ok": True, "action": "exists", "reason": "present"}
    return {"topic": topic, "ok": False, "action": "failed",
            "reason": out.strip()[:200] or f"termlink channel create exited {proc.returncode}"}


def default_reader(topic: str, cursor: int, limit: int = DEFAULT_LIMIT,
                   *, binary: str | None = None, timeout: int = 15) -> list[dict]:
    """Drain a topic from `cursor`. Returns raw envelopes, one per line."""
    argv = [binary or _binary(), "channel", "subscribe", topic, "--json",
            "--cursor", str(cursor), "--limit", str(limit)]
    try:
        proc = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return []
    if proc.returncode != 0:
        return []
    envelopes = []
    for line in (proc.stdout or "").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            envelopes.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return envelopes


def _decode(envelope: dict) -> str:
    import base64
    raw = envelope.get("payload_b64")
    if raw:
        try:
            return base64.b64decode(raw).decode("utf-8", "replace")
        except Exception:
            return ""
    return envelope.get("payload") or ""


#: T-3855 (ring20 §3.6): what a message with no sender metadata is called.
#: Never "unknown" — that reads as "we lost it"; this says what it is.
UNATTRIBUTED = "unattributed (raw post)"


def sender_of(meta: dict) -> str | None:
    """The sender's name from envelope metadata: `from_agent`, else the name
    its `from_circuit` carries. None only for a raw post with neither."""
    meta = meta or {}
    if meta.get("from_agent"):
        return str(meta["from_agent"])
    cid = str(meta.get("from_circuit") or "")
    if cid:
        parts = circuit.parse_circuit(cid)
        return parts.get("agent") or parts.get("project") or None
    return None


def sender_label(msg: dict) -> str:
    """How to NAME a message's sender to a human or agent (T-3855)."""
    return str(msg.get("from") or sender_of({"from_circuit": msg.get("from_circuit")})
               or UNATTRIBUTED)


def reply_address(msg: dict) -> str | None:
    """What to type as `--to` to answer `msg`. The sender's circuit when it
    lives on another hub (so the reply lands in ITS namespace, not ours);
    else its name. None for a raw post — there is nobody to address."""
    cid = str(msg.get("from_circuit") or "")
    if cid:
        from . import addressing
        bare = addressing.strip_host(cid)
        hub = circuit.parse_circuit(bare).get("hub")
        try:
            own = circuit.hub_id()
        except circuit.CircuitError:
            own = None
        if hub and hub != own:
            return bare
    return msg.get("from") or sender_of({"from_circuit": cid}) or None


#: Envelope msg_types that are delivery receipts, never mail (T-3792).
RECEIPT_MSG_TYPES = frozenset({"sidecar.receipt", "receipt"})
RECEIPT_BODY_PREFIX = "[sidecar receipt]"


def is_receipt(envelope: dict) -> bool:
    """A delivery receipt, by any of the three marks a sender has used (T-3792).

    `metadata.kind=receipt` is the current mark (T-3684). The envelope's own
    `msg_type` (`sidecar.receipt`, or termlink's `receipt`) and the fixed body
    prefix catch receipts whose metadata lacks `kind` — 055 measured ~24 of 28
    surfaced entries as receipts. A receipt only ever hides itself.
    """
    meta = envelope.get("metadata") or {}
    if meta.get("kind") == "receipt" or envelope.get("msg_type") in RECEIPT_MSG_TYPES:
        return True
    return _decode(envelope).lstrip().startswith(RECEIPT_BODY_PREFIX)


def surface_filter(msgs: list[dict], answered: set[str] | None = None) -> tuple[list[dict], dict]:
    """What the prompt-hook peek should show, and what it held back (T-3792).

    Held back, and COUNTED (the caller prints one line — never a silent drop):
      receipts          — anything `is_receipt` would have caught upstream
      answered_nudges   — `<base>-nudge-N` whose base consult we have already
                          answered (a REPLIED receipt sent for it)
      duplicate_nudges  — a further nudge for a base that is already shown
                          (itself, or a newer nudge for it)
    Newest first, so the nudge kept for a base is the latest one.
    """
    from .receipts import REPLIED, base_id, read_sent
    if answered is None:
        answered = {base_id(r.get("client_msg_id")) for r in read_sent()
                    if r.get("state") == REPLIED and r.get("ok")}
    counts = {"receipts": 0, "answered_nudges": 0, "duplicate_nudges": 0}
    present = {m.get("client_msg_id") for m in msgs
               if m.get("client_msg_id") and base_id(m["client_msg_id"]) == m["client_msg_id"]}

    def _off(m):
        o = m.get("offset")
        return o if isinstance(o, (int, float)) else -1

    kept, nudged = [], set()
    for m in sorted(msgs, key=_off, reverse=True):
        if (m.get("msg_type") in RECEIPT_MSG_TYPES
                or str(m.get("body") or "").lstrip().startswith(RECEIPT_BODY_PREFIX)):
            counts["receipts"] += 1
            continue
        cid = str(m.get("client_msg_id") or "")
        base = base_id(cid)
        if cid and base != cid:
            if base in answered:
                counts["answered_nudges"] += 1
                continue
            if base in present or base in nudged:
                counts["duplicate_nudges"] += 1
                continue
            nudged.add(base)
        kept.append(m)
    return kept, counts


def pending(agent: str | None = None, *, reader=default_reader,
            advance: bool = True, limit: int = DEFAULT_LIMIT) -> list[dict]:
    """Consults addressed to this agent that have not been shown before.

    Drains the `inbox:<circuit-id>` topic AND the legacy `sidecar:<agent>`
    alias (T-3433). Each topic keeps its own cursor — offsets are per-topic
    and comparing them across topics is meaningless — but the seen-set is
    SHARED, so a peer that posts to both during the transition, or a sender
    retrying past the hub's ~5-minute dedupe TTL (measured T-3405), surfaces
    once rather than twice.

    With `advance` (the default) the cursors and the seen-set move, so a
    second call returns nothing new. `advance=False` is a peek.
    """
    topics = read_topics(agent)  # T-3462: the one definition, shared with the sweep
    state = load_state()

    seen = list(state.get("seen") or [])
    seen_set = set(seen)
    # Seed from the per-topic seen-sets written before T-3433 made it shared,
    # so the transition does not re-surface anything already shown.
    for entry in state.get("topics", {}).values():
        for cmid in entry.get("seen") or []:
            if cmid not in seen_set:
                seen_set.add(cmid)
                seen.append(cmid)

    # T-3840: the one shown/answered ledger (lib/sidecar/seen.py). A consult
    # our agent already answered, or already had shown to it by the receiver
    # hook or an earlier drain, is not a pending consult — it is skipped
    # here (the cursor still moves past it), for the CLI and the watcher alike.
    from . import seen as seen_mod
    shown_table = seen_mod.shown()
    answered = seen_mod.answered_ids()

    fresh = []
    for topic in topics:
        entry = state["topics"].setdefault(topic, {"cursor": 0})
        highest = entry.get("cursor", 0)
        for env in reader(topic, highest, limit):
            offset = env.get("offset")
            if isinstance(offset, int):
                highest = max(highest, offset + 1)
            meta = env.get("metadata") or {}
            if is_receipt(env):
                # T-3684: a delivery receipt for a consult WE sent, posted to
                # our topic by a peer with no reachable receiver. It is ledger
                # data, never a consult: recorded (only if we really sent that
                # id to that peer) and never surfaced or counted as unread.
                from . import direct, receipts
                rf, rs = str(meta.get("receipt_for") or ""), str(meta.get("receipt_state") or "")
                note, since = meta.get("receipt_note"), meta.get("receipt_since")
                if not receipts.record_from_peer(rf, rs, meta.get("from_agent"),
                                                 via=f"hub:{topic}", note=note, since=since):
                    # T-3782: a receipt for a DIRECT-path send whose peer could
                    # not reach our receiver comes here too; the direct ledger
                    # applies the same "only what we sent, only from its
                    # addressee" rule.
                    direct.confirm_from_peer(rf, rs, meta.get("from_agent"),
                                             note=note, since=since)
                continue
            client_msg_id = meta.get("client_msg_id")
            # T-3782 (codex round 3): a duplicate is the same id WITH the same
            # content. The same id with different content is a second message
            # and must reach the receiver (watcher.ingest_hub keeps it under
            # its topic/offset id) — never be dropped here. A bare-id entry is
            # a pre-T-3782 seen record and still matches by id alone.
            seen_key = (f"{client_msg_id}#" + hashlib.sha256(
                str(env.get("payload_b64") or "").encode()).hexdigest()[:12]) if client_msg_id else None
            if client_msg_id and (seen_key in seen_set or client_msg_id in seen_set):
                continue  # duplicate the hub's TTL let through, or a dual post
            if client_msg_id:
                seen_set.add(seen_key)
                seen.append(seen_key)
                keys = seen_mod.keys_for(client_msg_id)
                if keys & answered or not seen_mod.may_show(keys, shown_table):
                    continue
            # T-3855: a sender that told us its circuit is a peer we can answer
            # on its own hub — learn it (the peer directory).
            if meta.get("from_circuit"):
                from . import addressing
                try:
                    addressing.learn(meta.get("from_agent"), meta.get("from_circuit"))
                except Exception:
                    pass
            fresh.append({
                "offset": offset,
                "topic": topic,
                "client_msg_id": client_msg_id,
                "from": sender_of(meta),
                "from_circuit": meta.get("from_circuit"),
                "conversation_id": meta.get("conversation_id"),
                "urgent": str(meta.get("urgent") or "").lower() in ("1", "true", "yes"),
                "body": _decode(env),
                "ts": env.get("ts"),
            })
        if advance:
            entry["cursor"] = highest

    if advance:
        # T-3840: merged under the ledger lock, so a `shown` row the receiver
        # hook wrote while this ran is not overwritten by this stale copy.
        with seen_mod.update() as disk:
            disk["topics"] = state["topics"]
            disk["seen"] = seen[-SEEN_CAP:]
            for entry in disk["topics"].values():
                entry.pop("seen", None)   # superseded by the shared set

    return fresh


def unread_summary(agent: str | None = None, *, reader=default_reader,
                   limit: int = DEFAULT_LIMIT,
                   now: datetime | None = None) -> dict:
    """What is sitting unread on this agent's consult inbox, per topic.

    T-3544 / OBS-567. Sibling of `dm.summary()` — same job on the rail peers
    are actually told to use — and the reason it exists is that until it did,
    nothing counted this. `fw audit` watched the OUTBOUND ledger, `fw doctor`
    watched `dm:*`, and an arriving consult was visible only to someone who
    chose to run `fw sidecar inbox` with no reason to think there was anything
    to read. 832 waited six days that way; 010-termlink found 49 of ours doing
    the same on their side.

    **This must not drain what it measures.** `pending()` moves cursors and
    the shared seen-set by default, so counting the naive way would consume
    the consult it was reporting — the OBS-566/T-3539 shape where the
    diagnostic destroys its own subject. The read here is `advance=False`,
    which touches no file; `tests/unit/test_sidecar_unread_summary.py` pins
    that by byte-comparing `inbox-state.json` across a call, with a control
    leg that fails against an advancing read.

    **Why this counts through `pending()` rather than offsets-minus-cursor.**
    The cheap arithmetic `dm._unread_count` uses is right for a DM rail, whose
    cursor is the whole story. A consult inbox additionally dedupes on
    `client_msg_id` across three alias topics, so records-past-cursor
    overstates owed work — measured here at 5 records versus 1 actual consult.
    Draining through the same function `fw sidecar inbox` uses means the number
    the WARN reports is exactly the number of consults the operator will be
    shown when they act on it. An alarm and its remedy that disagree teach
    people to distrust the alarm.
    """
    now_dt = now or datetime.now(timezone.utc)
    fresh = pending(agent, reader=reader, advance=False, limit=limit)

    by_topic: dict[str, list[dict]] = {}
    for msg in fresh:
        by_topic.setdefault(msg.get("topic") or "", []).append(msg)

    rows = []
    for topic, msgs in by_topic.items():
        oldest = None
        oldest_from = None
        for msg in msgs:
            ts_ms = msg.get("ts")
            if not isinstance(ts_ms, (int, float)):
                continue
            ts = datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc)
            if oldest is None or ts < oldest:
                oldest = ts
                oldest_from = msg.get("from")
        row = {
            "topic": topic,
            "unread": len(msgs),
            "oldest_unread_ts": oldest.isoformat() if oldest else None,
            "age_hours": (round((now_dt - oldest).total_seconds() / 3600, 1)
                          if oldest else None),
            "oldest_from": oldest_from,
        }
        rows.append(row)

    rows.sort(key=lambda r: r["topic"])
    return {"unread": len(fresh), "topics": rows}


def unread_stale(min_age_hours: float = 24, *, agent: str | None = None,
                 reader=default_reader, limit: int = DEFAULT_LIMIT,
                 now: datetime | None = None) -> list[dict]:
    """Consult-inbox topics holding an unread consult older than
    `min_age_hours` — the WARN shape for `fw doctor` and `fw audit`, mirroring
    `dm.stale()`.

    A topic whose oldest unread consult carries no usable timestamp is
    REPORTED, not skipped: an unread consult of unknown age is still owed work,
    and silently dropping it would reproduce the blindness this exists to end.
    Its `age_hours` comes back None so the caller can say "age unknown" rather
    than print a number it does not have.
    """
    snap = unread_summary(agent, reader=reader, limit=limit, now=now)
    return [r for r in snap["topics"]
            if r["age_hours"] is None or r["age_hours"] >= min_age_hours]
