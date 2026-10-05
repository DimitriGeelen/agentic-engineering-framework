"""arc-011 sidecar — the ONE seen/answered ledger for inbound mail (T-3840).

Two surfaces show inbound peer mail to the agent:
  * the UserPromptSubmit receiver hook (hooks.prompt, "# Sidecar receiver: …")
  * `fw sidecar inbox` (inbox.pending)

Before T-3840 they kept separate state: the inbox kept a seen-set in
.context/sidecar/inbox-state.json, the hook kept none at all. It relied
solely on the finalizer finding transcript evidence (HANDED_OVER); without
that evidence the message was released and surfaced again at every prompt.
The inbox's own `seen` list could not serve: the watcher drains the hub topic
through inbox.pending (watcher.py), so `seen` means "taken off the topic", not
"shown to the agent". Both surfaces now read and write ONE record, `shown`, in
the same inbox-state.json:

  shown      {msg id: {"n": times shown, "by": last surface}}, written under
             every id the message is known by (see keys_for). The hook
             writes it when it surfaces a message, and a draining
             `fw sidecar inbox` writes it for every consult it prints.

and derive "answered" from what we SENT (never from peer-written state):
  * receipts-sent.jsonl REPLIED rows (hub-path originals)
  * outbox/*.json `in_reply_to` (every `fw sidecar send --in-reply-to` via hub)
  * awaiting-ack.jsonl direct-ledger rows with `in_reply_to` (direct path)

Every id is reduced to its base (`<base>-nudge-N` → `<base>`), so answering a
nudge answers its consult and vice versa. Keys are message ids only, never the
sender, so mail from an "unknown" sender (hub-relayed, rescued) is covered.
"""

from __future__ import annotations

import fcntl
import json
import os
from contextlib import contextmanager
from pathlib import Path

#: How many times the receiver hook may surface one message. The second one is
#: allowed ONLY after the finalizer recorded HANDOVER_UNCONFIRMED (the harness
#: shows the model never got it). See hooks.prompt and T-3840 ## Decisions.
MAX_SURFACINGS = 2
SHOWN_CAP = 5000


def _root() -> Path:
    from . import receiver
    return receiver._root()


def state_path() -> Path:
    p = _root() / ".context" / "sidecar" / "inbox-state.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def _load(path: Path) -> dict:
    try:
        with open(path, encoding="utf-8") as fh:
            state = json.load(fh)
    except (OSError, json.JSONDecodeError):
        state = {}
    if not isinstance(state, dict):
        state = {}
    state.setdefault("topics", {})
    return state


def load() -> dict:
    return _load(state_path())


@contextmanager
def update():
    """Lock, load, yield the state for mutation, save atomically. The hook and
    the inbox CLI can run at the same moment; the lock keeps one from
    overwriting the other's additions."""
    path = state_path()
    lock = path.with_suffix(".json.lock")
    with open(lock, "a", encoding="utf-8") as lfh:
        fcntl.flock(lfh, fcntl.LOCK_EX)
        state = _load(path)
        yield state
        tmp = path.with_suffix(".json.tmp")
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(state, fh, indent=2)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, path)


def base(mid) -> str:
    from .receipts import base_id
    return base_id(str(mid or ""))


def keys_for(mid: str, msg: dict | None = None) -> set[str]:
    """Every id one receiver message is known by: the receiver's file id, the
    envelope's client_msg_id / msg_id, and the base of each."""
    ids = {str(mid or "")}
    for k in ("client_msg_id", "msg_id"):
        if msg and msg.get(k):
            ids.add(str(msg[k]))
    ids |= {base(i) for i in ids}
    ids.discard("")
    return ids


def shown(state: dict | None = None) -> dict:
    state = load() if state is None else state
    return dict(state.get("shown") or {})


def times_shown(keys: set[str], table: dict | None = None) -> int:
    table = shown() if table is None else table
    return max((int((table.get(k) or {}).get("n", 0)) for k in keys), default=0)


def answered_ids() -> set[str]:
    """Base ids of inbound messages our agent replied to (see module doc)."""
    from . import direct, outbox, receipts
    out: set[str] = set()
    for row in receipts.read_sent():
        if row.get("state") == receipts.REPLIED and row.get("client_msg_id"):
            out.add(base(row["client_msg_id"]))
    try:
        for p in outbox._outbox_dir().glob("*.json"):
            try:
                irt = json.loads(p.read_text(encoding="utf-8")).get("in_reply_to")
            except (OSError, json.JSONDecodeError):
                continue
            if irt:
                out.add(base(irt))
    except OSError:
        pass
    for row in direct.read_ledger():
        if row.get("in_reply_to"):
            out.add(base(row["in_reply_to"]))
    out.discard("")
    return out


def may_show(keys: set[str], table: dict | None = None,
             unconfirmed: bool = False) -> bool:
    """May a surface show this message (again)?

    Never shown → yes. Shown once → only if that showing is not proof it
    reached the agent: it was a non-draining peek (`by: peek`), or the hook's
    finalizer found no transcript evidence (`unconfirmed`). Shown twice → no.
    So a message that was peeked or lost can come back ONCE, never forever."""
    table = shown() if table is None else table
    n = times_shown(keys, table)
    if n == 0:
        return True
    if n >= MAX_SURFACINGS:
        return False
    last_by = {(table.get(k) or {}).get("by") for k in keys if k in table}
    return unconfirmed or "peek" in last_by


def unconfirmed_ids() -> set[str]:
    """Message ids whose LAST hand-over outcome is HANDOVER_UNCONFIRMED: the
    harness shows the model never got them (hook killed, output discarded)."""
    from . import receiver
    last: dict[str, str] = {}
    for row in receiver.read_events():
        if row.get("event") in ("HANDOVER_UNCONFIRMED", receiver.HANDED_OVER):
            last[str(row.get("msg_id"))] = row["event"]
    return {m for m, ev in last.items() if ev == "HANDOVER_UNCONFIRMED"}


def withheld(ids: list[str]) -> dict[str, str]:
    """{id: reason} for the receiver messages the prompt hook will NOT surface:
    answered (by any id it is known by, so a peer's `<id>-nudge-N` copy of mail
    we replied to counts), or shown as often as may_show allows.

    T-3872: the ONE predicate shared by the hook and the injector. With two,
    the injector kept typing "N peer messages waiting" for nudge copies the
    hook would never show, every REINJECT_AFTER_S, indefinitely."""
    from . import receiver
    if not ids:
        return {}
    table = shown()
    answered = answered_ids()
    unconfirmed = unconfirmed_ids() if table else set()
    out: dict[str, str] = {}
    for i in ids:
        keys = keys_for(i, receiver.read_message(i))
        if keys & answered:
            out[i] = "answered"
        elif not may_show(keys, table, unconfirmed=i in unconfirmed):
            out[i] = "already shown"
    return out


def mark_shown(entries: list[tuple[str, dict | None]], by: str) -> None:
    """Record that `by` showed these messages to the agent, under every id
    each is known by, so the other surface skips them too."""
    if not entries:
        return
    with update() as state:
        table = dict(state.get("shown") or {})
        for mid, msg in entries:
            keys = keys_for(mid, msg)
            n = times_shown(keys, table) + 1
            for key in keys:
                table.pop(key, None)
                table[key] = {"n": n, "by": by}
        if len(table) > SHOWN_CAP:
            table = dict(list(table.items())[-SHOWN_CAP:])
        state["shown"] = table
