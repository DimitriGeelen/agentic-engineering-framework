"""arc-011 sidecar — receipts for consults that arrive on the HUB TOPIC.

T-3684, operator 2026-10-03: "receipt telemetry on EVERY path". A consult
posted the pre-receiver way (a peer on an older install, or any send that
falls back to the hub) used to leave its sender with nothing but "the hub
accepted it" — lib/sidecar/inbox.py sent no receipt. Now whichever path takes
it off the topic tells the sender, once per state:

    RECEIVED     at once, when it is taken off the topic: the watcher's ingest
                 (watcher.ingest_hub), `fw sidecar inbox` (drain, after it has
                 printed), and the prompt hook's peek (sidecar-inbox.sh, for
                 exactly the consults it showed)
    HANDED_OVER  only on transcript evidence: after injection (hooks.finalize →
                 hooks._confirm), or after the peek hook's surfacing appears
                 in the session transcript under its one-time token (flush).
                 A `fw sidecar inbox` drain sends no HANDED_OVER: nothing
                 proves where its output went.
    REPLIED      when our agent's `fw sidecar send --in-reply-to` succeeded
    WAITING_NO_RECIPIENT  T-3782: the injector found no live recipient for it
                 (lib/sidecar/waiting.py) — carries the reason and the time
                 it started waiting; on EVERY receive path (direct and hub)
    DROPPED      T-3782: the operator closed it unhandled, with a reason

Delivery, receiver → sender:
  1. the sender's registered, live receiver: POST /ack {client_msg_id, state,
     peer} — the same authenticated call CONFIRM-2 uses;
  2. otherwise the sender's hub inbox topic, as a `kind=receipt` post
     (msg-type sidecar.receipt). inbox.pending() on a current install records
     it and never surfaces it as a consult. An install older than this one
     shows it as a short consult whose body says no action or reply is needed.

Sender side: a receipt is recorded ONLY for an id we sent through our outbox
to that same peer (a peer cannot invent rows or confirm someone else's mail),
in .context/sidecar/receipts.jsonl — append-only, separate from the hub-path
ack ledger, whose three-state machine and retry ladder (T-3434) stay untouched.
`fw sidecar latency` reads it.

Receiver side: what we sent, and how, is .context/sidecar/receipts-sent.jsonl
(the once-per-state dedupe, and the sender's identity for a later REPLIED).
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

from . import circuit, direct, lifecycle, outbox, receiver

RECEIVED = "RECEIVED"
HANDED_OVER = "HANDED_OVER"
REPLIED = "REPLIED"
WAITING = "WAITING_NO_RECIPIENT"   # T-3782
DROPPED = "DROPPED"                # T-3782
STATES = (RECEIVED, HANDED_OVER, REPLIED, WAITING, DROPPED)
KIND = "receipt"


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _sidecar() -> Path:
    d = receiver._root() / ".context" / "sidecar"
    d.mkdir(parents=True, exist_ok=True)
    return d


def ledger_path() -> Path:
    return _sidecar() / "receipts.jsonl"


def sent_path() -> Path:
    return _sidecar() / "receipts-sent.jsonl"


def _read(path: Path) -> list[dict]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    out = []
    for ln in lines:
        try:
            out.append(json.loads(ln))
        except json.JSONDecodeError:
            continue
    return out


def _append(path: Path, row: dict) -> None:
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row) + "\n")


def read_ledger() -> list[dict]:
    return _read(ledger_path())


_NUDGE_SUFFIX = re.compile(r"-nudge-\d+$")


def base_id(client_msg_id: str | None) -> str:
    """The consult a nudge points at (T-3804). The retry ladder posts nudges
    as `<base>-nudge-N` (retry.default_nudge); a receipt or reply naming one
    is about the base consult, which is the only id the sender's outbox and
    ladder know."""
    return _NUDGE_SUFFIX.sub("", str(client_msg_id or ""))


def replied_ids() -> set[str]:
    """Base ids of consults WE sent that the addressee has REPLIED to (T-3804).

    Every REPLIED receipt lands here, whichever way it came — the hub topic
    (inbox.pending) or our receiver's POST /ack — and record_from_peer has
    already checked it is from the addressee of a message we really sent. The
    retry sweep reads this so a reply settles the ladder."""
    return {base_id(r.get("client_msg_id")) for r in read_ledger()
            if r.get("state") == REPLIED and r.get("client_msg_id")}


def read_sent() -> list[dict]:
    return _read(sent_path())


def _me() -> str:
    try:
        return circuit.agent_name()
    except circuit.CircuitError:
        return receiver._root().name


# ── sender side ─────────────────────────────────────────────────────────────

def record_from_peer(client_msg_id: str, state: str, peer: str | None, via: str,
                     note: str | None = None, since: str | None = None) -> bool:
    """Record a receipt for a message WE sent through the outbox to `peer`.
    False (nothing written) for an unknown id, a state that is not a receipt,
    a peer that is not the addressee, or a state already recorded."""
    if state not in STATES or not peer or not client_msg_id:
        return False
    # T-3804: a receipt for one of our nudges is a receipt for its consult.
    client_msg_id = base_id(client_msg_id)
    if "/" in client_msg_id or ".." in client_msg_id:
        return False
    try:
        msg = json.loads((outbox._outbox_dir() / f"{client_msg_id}.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    if direct._name(msg.get("to")) != direct._name(peer):
        return False
    if any(r.get("client_msg_id") == client_msg_id and r.get("state") == state
           for r in read_ledger()):
        return False
    row = {"client_msg_id": client_msg_id, "state": state,
           "by": f"peer:{direct._name(peer)}", "via": via, "ts": _now()}
    if note:
        row["note"] = str(note)[:300]
    if since:
        row["since"] = str(since)[:64]
    _append(ledger_path(), row)
    return True


# ── receiver side ───────────────────────────────────────────────────────────

def _already(client_msg_id: str, state: str) -> bool:
    return any(r.get("client_msg_id") == client_msg_id and r.get("state") == state
               and r.get("ok") for r in read_sent())


already = _already


def origin(client_msg_id: str) -> dict | None:
    """Who sent a hub-topic message we took: from the receiver store, else
    from our own receipts-sent ledger (a message drained by `fw sidecar
    inbox` is never stored in the receiver)."""
    msg = receiver.read_message(client_msg_id) if client_msg_id else None
    if msg and msg.get("via") == "hub-topic":
        return {"client_msg_id": client_msg_id, "from": msg.get("from"),
                "from_circuit": msg.get("from_circuit"),
                "conversation_id": msg.get("conversation_id")}
    for r in reversed(read_sent()):
        if r.get("client_msg_id") == client_msg_id:
            return {"client_msg_id": client_msg_id, "from": r.get("to"),
                    "from_circuit": r.get("to_circuit"),
                    "conversation_id": r.get("conversation_id")}
    return None


def _hub_post(client_msg_id: str, state: str, sender: str, sender_circuit: str | None,
              conversation_id: str | None, runner=subprocess.run,
              note: str | None = None, since: str | None = None) -> tuple[bool, str]:
    try:
        topic = circuit.topic_for_name(sender_circuit or sender)
    except circuit.CircuitError as e:
        return False, f"no topic for {sender!r}: {e}"
    # T-3855: the receipt goes to the SENDER's hub. A from_circuit names it;
    # a hub that is not ours needs the hubs.toml profile that reaches it, and
    # with none the receipt is reported failed — never posted to our own hub,
    # where the sender would never read it.
    hub_arg = None
    if sender_circuit:
        from . import addressing
        sender_hub = circuit.parse_circuit(addressing.strip_host(sender_circuit)).get("hub")
        if sender_hub:
            try:
                hub_arg = addressing.hub_arg_for(sender_hub, runner=runner)
            except circuit.CircuitError as e:
                return False, f"sender hub {sender_hub} unreachable for a receipt: {e}"[:300]
    me = _me()
    body = (f"[sidecar receipt] {state} for message {client_msg_id} from {me}. "
            + (f"{note}" + (f" (since {since}). " if since else ". ") if note else "")
            + "Automatic delivery receipt — no action or reply needed.")
    argv = ["termlink", "channel", "post", topic, "--json", "--ensure-topic",
            "--msg-type", "sidecar.receipt",
            "--client-msg-id", f"rcpt-{state.lower()}-{client_msg_id}"[:128],
            "--metadata", f"kind={KIND}",
            "--metadata", f"receipt_for={client_msg_id}",
            "--metadata", f"receipt_state={state}",
            "--metadata", f"from_agent={me}",
            "--metadata", f"conversation_id={conversation_id or '-'}"]
    try:
        argv += ["--metadata", f"from_circuit={circuit.circuit_id('full')}"]
    except circuit.CircuitError:
        pass
    if note:
        argv += ["--metadata", f"receipt_note={str(note)[:200]}"]
    if since:
        argv += ["--metadata", f"receipt_since={since}"]
    argv += ["--payload", body]
    if hub_arg:
        argv += ["--hub", hub_arg]
    try:
        proc = runner(argv, capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.SubprocessError) as e:
        return False, f"hub post failed: {e}"[:200]
    if proc.returncode != 0:
        return False, f"hub post exit {proc.returncode}: {(proc.stderr or '').strip()[:160]}"
    return True, (f"{topic}@{hub_arg}" if hub_arg else topic)


def send(env: dict, state: str, *, by: str, runner=subprocess.run,
         note: str | None = None, since: str | None = None) -> dict:
    """Tell the sender of hub-topic message `env` that it reached `state`.
    Once per (message, state). Returns the receipts-sent row."""
    cid = str(env.get("client_msg_id") or "")
    sender = env.get("from")
    row = {"client_msg_id": cid, "state": state, "by": by, "to": sender,
           "to_circuit": env.get("from_circuit"),
           "conversation_id": env.get("conversation_id"), "ts": _now()}
    if note:
        row["note"] = str(note)[:300]
    if since:
        row["since"] = since
    if state not in STATES or not cid or not sender:
        row.update(ok=False, via=None, error="not a receipt-able message (no id or sender)")
        _append(sent_path(), row)
        return row
    if _already(cid, state):
        return dict(row, ok=True, via="already-sent")
    ok, via, err = False, None, None
    entry = lifecycle.lookup(str(sender))
    if entry and entry.get("live"):
        try:
            payload = {"client_msg_id": cid, "state": state, "peer": _me()}
            if note:
                payload["note"] = str(note)[:300]
            if since:
                payload["since"] = since
            status, resp = direct.post_with_token(entry, "/ack", payload)
            ok = status == 200 and resp.get("recorded") is True
            via = "direct"
            err = None if ok else f"HTTP {status} {resp}"[:200]
        except OSError as e:
            err = f"receiver unreachable: {e}"[:200]
    if not ok:
        hub_ok, detail = _hub_post(cid, state, str(sender), env.get("from_circuit"),
                                   env.get("conversation_id"), runner, note=note, since=since)
        if hub_ok:
            ok, via, err = True, f"hub:{detail}", None
        else:
            err = "; ".join(x for x in (err, detail) if x)
    row.update(ok=ok, via=via, error=err)
    _append(sent_path(), row)
    if receiver.read_message(cid) is not None:
        receiver.record_event(cid, "RECEIPT_SENT" if ok else "RECEIPT_FAILED",
                              state=state, via=via, error=err)
    return row


def send_detached(messages: list[dict], states: list[str], by: str) -> None:
    """Send receipts from a detached process — for the prompt hook, which must
    return within its timeout and cannot wait on a hub post."""
    todo = [m for m in messages if m.get("client_msg_id") and m.get("from")
            and not all(_already(m["client_msg_id"], s) for s in states)]
    if not todo:
        return
    qdir = _sidecar() / "receipts-queue"
    qdir.mkdir(exist_ok=True)
    path = qdir / f"{uuid.uuid4()}.json"
    path.write_text(json.dumps({"messages": todo, "states": states, "by": by}), encoding="utf-8")
    cli = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sidecar_cli.py")
    subprocess.Popen([sys.executable, cli, "receipts-flush", str(path)],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True,
                     env=dict(os.environ, PROJECT_ROOT=str(receiver._root())))


FINALIZE_WAIT_S = float(os.environ.get("FW_SIDECAR_RECEIPT_WAIT_S") or 90)


def _peek_in_transcript(transcript: str, header: str, surfacing: str) -> bool:
    """Does the session transcript hold THIS surfacing's hook attachment with
    the exact header line for the consult? (The harness's record, not ours.)"""
    if not transcript or not header or not surfacing or surfacing not in header:
        return False
    try:
        text = Path(transcript).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False
    for line in text.splitlines():
        if surfacing not in line or "hook_additional_context" not in line:
            continue
        try:
            att = json.loads(line).get("attachment") or {}
        except json.JSONDecodeError:
            continue
        if att.get("type") != "hook_additional_context":
            continue
        content = att.get("content")
        body = "\n".join(content) if isinstance(content, list) else str(content)
        if header in body.splitlines():
            return True
    return False


def flush(path: str, wait_s: float = FINALIZE_WAIT_S, poll_s: float = 1.0) -> list[dict]:
    """Run a queued receipt job. With `finalize` (the prompt hook's peek), also
    send HANDED_OVER for each consult the transcript proves the model was
    given in that surfacing — and never otherwise."""
    import time
    p = Path(path)
    try:
        job = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    by = job.get("by") or "queue"
    rows = [send(m, s, by=by) for m in job.get("messages", []) for s in job.get("states", [])]
    fin = job.get("finalize") or {}
    pending = [m for m in job.get("messages", []) if m.get("_header")]
    deadline = time.time() + wait_s
    while fin.get("transcript") and pending:
        for m in list(pending):
            if _peek_in_transcript(fin["transcript"], m["_header"], fin.get("surfacing") or ""):
                rows.append(send(m, HANDED_OVER, by=by))
                pending.remove(m)
        if not pending or time.time() >= deadline:
            break
        time.sleep(poll_s)
    p.unlink(missing_ok=True)
    return rows
