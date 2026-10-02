"""arc-011 sidecar — direct (receiver-to-receiver) send path and sender ledger.

T-3693 (arc-011 slice 1, finishing T-3561). The design (D-645 §2) is one verb:
call the peer's receiver API. This module is that call, plus the sender-side
ledger that records what happened to each message, each state written by the
party that can know it:

    SENT          us, before the call
    RECEIVED      us, from the receiver's HTTP response (CONFIRM-1)
    HANDED_OVER   our receiver, when the peer's receiver posts CONFIRM-2 — which
                  the peer's prompt hook sends only after it surfaced the
                  message to the peer agent
    REPLIED       our receiver, when a message answering this one is stored
    UNDELIVERABLE us, when the receiver is down and the retry budget is spent
    REJECTED      us, from a 401 (bad token) or 409 (id reused with other content)
    ESCALATED     infrastructure (`fw sidecar sweep`), when HANDED_OVER has not
                  arrived by the message's deadline

Ledger: .context/sidecar/direct-ack.jsonl (append-only; latest row per id wins).
It is separate from the hub path's awaiting-ack.jsonl on purpose: that ledger's
three-state machine and retry ladder (T-3434) are the hub fallback's and are
left untouched.

Every non-success outcome is also appended to .context/sidecar/refusals.jsonl,
recorded for the T-3555 refusal ledger, which has not shipped.
"""

from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from . import lifecycle, receiver

SENT = "SENT"
RECEIVED = "RECEIVED"
HANDED_OVER = "HANDED_OVER"
REPLIED = "REPLIED"
UNDELIVERABLE = "UNDELIVERABLE"
REJECTED = "REJECTED"
ESCALATED = "ESCALATED"
NON_SUCCESS = frozenset({UNDELIVERABLE, REJECTED, ESCALATED})

DEFAULT_HANDOVER_DEADLINE_S = 900   # 15 min — the retry ladder's first escalation rung
DEFAULT_RETRIES = 3
_BACKOFF_S = (0.5, 1.0, 2.0, 4.0)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _ledger_path() -> Path:
    p = receiver._root() / ".context" / "sidecar" / "direct-ack.jsonl"
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def _refusals_path() -> Path:
    return receiver._root() / ".context" / "sidecar" / "refusals.jsonl"


def record(client_msg_id: str, state: str, *, by: str, **fields) -> dict:
    """Append one ledger row. `by` names the party that set the state."""
    row = {"client_msg_id": client_msg_id, "state": state, "by": by,
           "ts": _now().isoformat()}
    row.update({k: v for k, v in fields.items() if v is not None})
    with open(_ledger_path(), "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row) + "\n")
    if state in NON_SUCCESS:
        with open(_refusals_path(), "a", encoding="utf-8") as fh:
            fh.write(json.dumps({"source": "sidecar-direct", "for": "T-3555",
                                 **row}) + "\n")
    return row


def read_ledger() -> list[dict]:
    path = _ledger_path()
    if not path.exists():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows


def history(client_msg_id: str) -> list[dict]:
    return [r for r in read_ledger() if r.get("client_msg_id") == client_msg_id]


def latest() -> dict[str, dict]:
    """Latest row per id, carrying the first row's message metadata."""
    out: dict[str, dict] = {}
    for row in read_ledger():
        cid = str(row.get("client_msg_id") or "")
        merged = dict(out.get(cid, {}))
        merged.update(row)
        out[cid] = merged
    return out


def latest_state(client_msg_id: str) -> str | None:
    rows = history(client_msg_id)
    return rows[-1]["state"] if rows else None


# ── HTTP ────────────────────────────────────────────────────────────────────

def _post(url: str, path: str, token: str, payload: dict, timeout: float = 5.0):
    """POST JSON; returns (status, body-dict). Raises OSError on no connection."""
    req = urllib.request.Request(
        f"{url}{path}", data=json.dumps(payload).encode("utf-8"), method="POST",
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read() or b"{}")
        except json.JSONDecodeError:
            body = {}
        return e.code, body
    except urllib.error.URLError as e:
        raise OSError(str(e.reason)) from e


def post_with_token(entry: dict, path: str, payload: dict,
                    token: str | None = None):
    """POST to a registered receiver using the token from its token_file."""
    if token is None:
        token = lifecycle.read_token(Path(entry.get("token_file", ""))) or ""
    return _post(entry["url"], path, token, payload)


# ── send ────────────────────────────────────────────────────────────────────

def send(entry: dict, *, from_id: str, to: str, body: str, conversation_id: str,
         urgent: bool = False, in_reply_to: str | None = None,
         handover_deadline_s: int = DEFAULT_HANDOVER_DEADLINE_S,
         retries: int = DEFAULT_RETRIES, token: str | None = None,
         sleep=time.sleep) -> dict:
    """Send one message to a registered receiver. Returns the final ledger row.

    `token` overrides the token read from the peer's token_file (tests use it
    to prove a bad token is REJECTED).
    """
    client_msg_id = str(uuid.uuid4())
    envelope = {
        "client_msg_id": client_msg_id,
        "from": from_id,
        "to": to,
        "conversation_id": conversation_id,
        "in_reply_to": in_reply_to,
        "urgent": bool(urgent),
        "body": body,
        "created_at": _now().isoformat(),
    }
    record(client_msg_id, SENT, by="sender", target=to, url=entry.get("url"),
           conversation_id=conversation_id, in_reply_to=in_reply_to)

    last_error = None
    for attempt in range(1, retries + 1):
        try:
            status, resp = post_with_token(entry, "/message", envelope, token=token)
        except OSError as e:
            last_error = f"receiver unreachable: {e}"
            if attempt < retries:
                sleep(_BACKOFF_S[min(attempt - 1, len(_BACKOFF_S) - 1)])
            continue
        if status == 200 and resp.get("status") == RECEIVED:
            deadline = (_now() + timedelta(seconds=handover_deadline_s)).isoformat()
            return record(client_msg_id, RECEIVED, by="receiver-response",
                          deadline=deadline, attempts=attempt)
        if status in (401, 403):
            return record(client_msg_id, REJECTED, by="receiver-response",
                          error=f"HTTP {status}: {resp.get('error', 'unauthorized')}",
                          attempts=attempt)
        if status in (400, 409, 413):
            return record(client_msg_id, REJECTED, by="receiver-response",
                          error=f"HTTP {status}: {resp.get('error', '')}",
                          attempts=attempt)
        last_error = f"HTTP {status}: {resp.get('error', '')}"
        if attempt < retries:
            sleep(_BACKOFF_S[min(attempt - 1, len(_BACKOFF_S) - 1)])
    return record(client_msg_id, UNDELIVERABLE, by="sender",
                  error=f"retry budget spent ({retries} attempts): {last_error}",
                  attempts=retries)


# ── peer-set states (called by OUR receiver) ────────────────────────────────

def confirm_from_peer(client_msg_id: str, state: str, peer: str | None) -> bool:
    """CONFIRM-2 arrived at our receiver: record HANDED_OVER for a message we
    sent. Only HANDED_OVER may be confirmed this way, and only for an id this
    ledger knows — a peer cannot invent rows."""
    if state != HANDED_OVER or not history(client_msg_id):
        return False
    record(client_msg_id, HANDED_OVER, by=f"peer-receiver:{peer or 'unknown'}")
    return True


def note_reply(envelope: dict) -> str | None:
    """A message just stored by our receiver may answer one we sent. If so,
    record REPLIED on the original and return its id.

    Explicit `in_reply_to` wins; otherwise the newest open message we sent to
    the same peer on the same conversation is the one answered.
    """
    rows = latest()
    target = envelope.get("in_reply_to")
    if target and target in rows:
        original = target
    else:
        sender, conv = envelope.get("from"), envelope.get("conversation_id")
        candidates = [r for r in rows.values()
                      if r.get("target") == sender and r.get("conversation_id") == conv
                      and r.get("state") not in (REPLIED, REJECTED, UNDELIVERABLE)]
        if not candidates:
            return None
        original = candidates[-1]["client_msg_id"]
    if rows[original].get("state") == REPLIED:
        return original
    record(original, REPLIED, by="own-receiver",
           reply_msg_id=envelope.get("client_msg_id"))
    return original


# ── infrastructure ──────────────────────────────────────────────────────────

def escalate_expired(now: str | None = None) -> list[str]:
    """Flip every RECEIVED message whose HANDED_OVER deadline has passed to
    ESCALATED. Retrying would not help — the receiver HAS the message and the
    agent never got it — so this is an escalation, not a retry."""
    now_dt = datetime.fromisoformat(now) if now else _now()
    flipped = []
    for cid, row in latest().items():
        if row.get("state") != RECEIVED:
            continue
        deadline = row.get("deadline")
        if deadline and now_dt > datetime.fromisoformat(deadline):
            record(cid, ESCALATED, by="infrastructure",
                   error=f"HANDED_OVER not confirmed by deadline {deadline}")
            flipped.append(cid)
    return flipped
