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

import json
import os
import shutil
import subprocess

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

    fresh = []
    for topic in topics:
        entry = state["topics"].setdefault(topic, {"cursor": 0})
        highest = entry.get("cursor", 0)
        for env in reader(topic, highest, limit):
            offset = env.get("offset")
            if isinstance(offset, int):
                highest = max(highest, offset + 1)
            meta = env.get("metadata") or {}
            client_msg_id = meta.get("client_msg_id")
            if client_msg_id and client_msg_id in seen_set:
                continue  # duplicate the hub's TTL let through, or a dual post
            if client_msg_id:
                seen_set.add(client_msg_id)
                seen.append(client_msg_id)
            fresh.append({
                "offset": offset,
                "topic": topic,
                "client_msg_id": client_msg_id,
                "from": meta.get("from_agent"),
                "from_circuit": meta.get("from_circuit"),
                "conversation_id": meta.get("conversation_id"),
                "body": _decode(env),
                "ts": env.get("ts"),
            })
        if advance:
            entry["cursor"] = highest

    if advance:
        state["seen"] = seen[-SEEN_CAP:]
        for entry in state.get("topics", {}).values():
            entry.pop("seen", None)   # superseded by the shared set
        save_state(state)

    return fresh
