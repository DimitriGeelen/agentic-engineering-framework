"""arc-011 sidecar — receipts for consults that arrive on the HUB TOPIC.

T-3684, operator 2026-10-03: "receipt telemetry on EVERY path". A consult
posted the pre-receiver way (a peer on an older install, or any send that
falls back to the hub) used to leave its sender with nothing but "the hub
accepted it" — lib/sidecar/inbox.py sent no receipt. Now whichever path takes
it off the topic tells the sender, once per state:

    RECEIVED     at once, when it is taken off the topic: the watcher's ingest
                 (watcher.ingest_hub), `fw sidecar inbox` (drain), and the
                 prompt hook's peek (sidecar-inbox.sh → `inbox --peek --receipt`)
    HANDED_OVER  on injection, once the session transcript proves the model
                 was given it (hooks.finalize → hooks._confirm), or when
                 `fw sidecar inbox` printed it into the agent's own tool output
    REPLIED      when our agent answers it with `fw sidecar send --in-reply-to`

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
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

from . import circuit, direct, lifecycle, outbox, receiver

RECEIVED = "RECEIVED"
HANDED_OVER = "HANDED_OVER"
REPLIED = "REPLIED"
STATES = (RECEIVED, HANDED_OVER, REPLIED)
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


def read_sent() -> list[dict]:
    return _read(sent_path())


def _me() -> str:
    try:
        return circuit.agent_name()
    except circuit.CircuitError:
        return receiver._root().name


# ── sender side ─────────────────────────────────────────────────────────────

def record_from_peer(client_msg_id: str, state: str, peer: str | None, via: str) -> bool:
    """Record a receipt for a message WE sent through the outbox to `peer`.
    False (nothing written) for an unknown id, a state that is not a receipt,
    a peer that is not the addressee, or a state already recorded."""
    if state not in STATES or not peer or not client_msg_id:
        return False
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
    _append(ledger_path(), {"client_msg_id": client_msg_id, "state": state,
                            "by": f"peer:{direct._name(peer)}", "via": via, "ts": _now()})
    return True


# ── receiver side ───────────────────────────────────────────────────────────

def _already(client_msg_id: str, state: str) -> bool:
    return any(r.get("client_msg_id") == client_msg_id and r.get("state") == state
               and r.get("ok") for r in read_sent())


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
              conversation_id: str | None, runner=subprocess.run) -> tuple[bool, str]:
    try:
        topic = circuit.topic_for_name(sender_circuit or sender)
    except circuit.CircuitError as e:
        return False, f"no topic for {sender!r}: {e}"
    me = _me()
    body = (f"[sidecar receipt] {state} for message {client_msg_id} from {me}. "
            "Automatic delivery receipt — no action or reply needed.")
    argv = ["termlink", "channel", "post", topic, "--json", "--ensure-topic",
            "--msg-type", "sidecar.receipt",
            "--client-msg-id", f"rcpt-{state.lower()}-{client_msg_id}"[:128],
            "--metadata", f"kind={KIND}",
            "--metadata", f"receipt_for={client_msg_id}",
            "--metadata", f"receipt_state={state}",
            "--metadata", f"from_agent={me}",
            "--metadata", f"conversation_id={conversation_id or '-'}",
            "--payload", body]
    try:
        proc = runner(argv, capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.SubprocessError) as e:
        return False, f"hub post failed: {e}"[:200]
    if proc.returncode != 0:
        return False, f"hub post exit {proc.returncode}: {(proc.stderr or '').strip()[:160]}"
    return True, topic


def send(env: dict, state: str, *, by: str, runner=subprocess.run) -> dict:
    """Tell the sender of hub-topic message `env` that it reached `state`.
    Once per (message, state). Returns the receipts-sent row."""
    cid = str(env.get("client_msg_id") or "")
    sender = env.get("from")
    row = {"client_msg_id": cid, "state": state, "by": by, "to": sender,
           "to_circuit": env.get("from_circuit"),
           "conversation_id": env.get("conversation_id"), "ts": _now()}
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
            status, resp = direct.post_with_token(
                entry, "/ack", {"client_msg_id": cid, "state": state, "peer": _me()})
            ok = status == 200 and resp.get("recorded") is True
            via = "direct"
            err = None if ok else f"HTTP {status} {resp}"[:200]
        except OSError as e:
            err = f"receiver unreachable: {e}"[:200]
    if not ok:
        hub_ok, detail = _hub_post(cid, state, str(sender), env.get("from_circuit"),
                                   env.get("conversation_id"), runner)
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


def flush(path: str) -> list[dict]:
    p = Path(path)
    try:
        job = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    rows = [send(m, s, by=job.get("by") or "queue")
            for m in job.get("messages", []) for s in job.get("states", [])]
    p.unlink(missing_ok=True)
    return rows
