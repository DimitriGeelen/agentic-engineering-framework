"""arc-011 sidecar receiver — HTTP API for receiving peer consults.

T-3561 (arc-011 slice 1). A durable, per-agent HTTP server that receives
messages durably and confirms receipt. This is the keystone: every other
slice depends on a process that exists.

Architecture:
  - Runs as a separate process per agent, with a stable HTTP address
  - Stores messages durably in .context/sidecar/inbox/<msg_id>.json
  - Sets a dirty-bit flag AFTER successful message write
  - Returns RECEIVED immediately (sender-side confirmation)
  - Injection (lib/sidecar/inject.py) types ONE line into the agent's TermLink
    session when the agent is ready; the UserPromptSubmit hook
    (lib/sidecar/hooks.py) then surfaces the stored message and records
    HANDED_OVER — never the queue write, never the inject alone (T-3693)
  - Authenticated: bearer token checked against receiver.token (http_server.py)

Per D-645 §2 (round trip):
  - Step 3: store message locally, atomic with flag
  - Step 4: set flag file (dirty-bit)
  - Step 5: CONFIRM-1 "received" → sender's API
  - Step 7-9: tick → ready check → inject → CONFIRM-2 "handed over"

Message storage layout:
  .context/sidecar/receiver/
    messages/<msg_id>.json     — message envelope (durable)
    messages/<msg_id>.ready    — dirty-bit flag (receiver-side)
    messages/<msg_id>.pending  — HANDED_OVER record (written by the prompt hook)
    events.jsonl               — append-only receiver event ledger
  .context/sidecar/receiver.{pid,port,url,token}  — triple-file + auth token
"""

from __future__ import annotations

import hashlib
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

# States set by different parties (per D-645, T-3561 AC):
# RECEIVED: set by receiver after durable store
# HANDED_OVER: set by receiver after injection
# REJECTED: set by receiver if auth fails
# ESCALATED: set by infrastructure on deadline
RECEIVED = "RECEIVED"
HANDED_OVER = "HANDED_OVER"
REJECTED = "REJECTED"
ESCALATED = "ESCALATED"
UNDELIVERABLE = "UNDELIVERABLE"


# A message id becomes a filename and appears in the one injected line, so it
# is held to a strict charset: no path separators, no dots, no whitespace or
# control characters (a newline would split the "one line" into two prompts).
_MSG_ID_RE = re.compile(r"[A-Za-z0-9_:-]{1,128}")


def _framework_root() -> Path:
    """Where the framework code lives."""
    env = os.environ.get("FRAMEWORK_ROOT")
    if env:
        return Path(env)
    return Path(__file__).resolve().parents[2]


def _is_project_root(d: Path) -> bool:
    return (d / ".framework.yaml").is_file() or (
        (d / "FRAMEWORK.md").is_file() and (d / "bin" / "fw").is_file())


def _root() -> Path:
    """The CONSUMER project root (same logic as outbox.py)."""
    env = os.environ.get("PROJECT_ROOT")
    if env:
        return Path(env)
    cwd = Path.cwd().resolve()
    for d in (cwd, *cwd.parents):
        if _is_project_root(d):
            return d
    fw = _framework_root()
    if fw.name == ".agentic-framework":
        return fw.parent
    return fw


def _receiver_dir() -> Path:
    """Root directory for receiver state."""
    d = _root() / ".context" / "sidecar" / "receiver"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _messages_dir() -> Path:
    """Directory for stored message files."""
    d = _receiver_dir() / "messages"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _ready_flag_path(msg_id: str) -> Path:
    """Path to the receiver-side dirty-bit flag (message is ready to inject)."""
    return _messages_dir() / f"{msg_id}.ready"


def _message_path(msg_id: str) -> Path:
    """Path to the stored message file."""
    return _messages_dir() / f"{msg_id}.json"


def _pending_path(msg_id: str) -> Path:
    """Path to pending state file (receiver tracking injection status)."""
    return _messages_dir() / f"{msg_id}.pending"


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _canonical_hash(envelope: dict) -> str:
    """Content hash of an envelope, independent of key order and transport noise.

    A retry of the same message carries the same id AND the same content; a
    reused id with different content is a different message wearing a stolen
    id, and must be refused rather than silently answered with the old one.
    """
    body = {k: v for k, v in envelope.items() if not k.startswith("_")}
    raw = json.dumps(body, sort_keys=True, ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def _events_path() -> Path:
    return _receiver_dir() / "events.jsonl"


def record_event(msg_id: str, event: str, **detail) -> None:
    """Append one row to the receiver's own event ledger (append-only).

    This is the receiver-side record of what happened to a message it holds:
    STORED, INJECT_ATTEMPT, INJECT_BLOCKED, HANDED_OVER, CONFIRM_SENT,
    CONFIRM_FAILED, REJECTED. HANDED_OVER is written ONLY by the prompt hook
    after it has emitted the message (lib/sidecar/hooks.py) — an injection
    attempt or a queue write never produces it.
    """
    row = {"msg_id": msg_id, "event": event, "ts": _now_iso()}
    row.update({k: v for k, v in detail.items() if v is not None})
    with open(_events_path(), "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row) + "\n")


def read_events(msg_id: str | None = None) -> list[dict]:
    path = _events_path()
    if not path.exists():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if msg_id is None or row.get("msg_id") == msg_id:
            rows.append(row)
    return rows


def store_message(msg_id: str, envelope: dict) -> tuple[bool, str]:
    """Store a message durably, then set its dirty-bit flag.

    Returns (success, error). On success the message file and the flag are
    both on disk and the caller may answer RECEIVED. A retry of the same id
    with the same content is idempotent; the same id with different content
    returns (False, "conflict: ...").
    """
    if not isinstance(msg_id, str) or not _MSG_ID_RE.fullmatch(msg_id):
        return False, "invalid client_msg_id (allowed: [A-Za-z0-9_:-], 1-128 chars)"

    msg_path = _message_path(msg_id)
    ready_path = _ready_flag_path(msg_id)
    digest = _canonical_hash(envelope)

    if msg_path.exists():
        stored = read_message(msg_id) or {}
        if stored.get("_content_sha256") != digest:
            return False, "conflict: client_msg_id reused with different content"
        if not ready_path.exists():
            # Torn write from an earlier attempt: the message is complete (it
            # was renamed into place), only the flag is missing. Finish it.
            _write_flag(ready_path)
        return True, ""

    record = dict(envelope)
    record["_content_sha256"] = digest
    record["_stored_at"] = _now_iso()
    tmp_path = msg_path.with_suffix(".json.tmp")
    try:
        with open(tmp_path, "w", encoding="utf-8") as fh:
            json.dump(record, fh, indent=2)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_path, msg_path)
    except OSError as e:
        try:
            tmp_path.unlink()
        except OSError:
            pass
        return False, f"failed to write message: {e}"

    # The flag is written only after the message is fully in place: a crash
    # between the two leaves a complete message with no flag (finished on the
    # retry above), never a flag pointing at a partial message.
    try:
        _write_flag(ready_path)
    except OSError as e:
        return False, f"failed to write ready flag: {e}"
    record_event(msg_id, "STORED", sender=envelope.get("from"))
    return True, ""


def _write_flag(path: Path) -> None:
    with open(path, "w", encoding="utf-8") as fh:
        fh.flush()
        os.fsync(fh.fileno())


def list_pending_messages() -> list[str]:
    """Return message IDs that have both message and ready-flag files.

    A message file with no flag is an incomplete/torn write and is not surfaced.
    """
    msg_dir = _messages_dir()
    ready_flags = {p.stem for p in msg_dir.glob("*.ready")}
    messages = {p.stem for p in msg_dir.glob("*.json")}
    # Only return IDs that have BOTH files
    return sorted(ready_flags & messages)


def read_message(msg_id: str) -> dict | None:
    """Read a stored message file."""
    path = _message_path(msg_id)
    if not path.exists():
        return None
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return None


def mark_handed_over(msg_id: str, evidence: str | None = None) -> None:
    """Record that a message reached the agent. Called ONLY by the hook
    finalizer once the session transcript shows the model was given it
    (lib/sidecar/hooks.py:finalize) — never by the injector, never on store."""
    pending_path = _pending_path(msg_id)
    state = {"msg_id": msg_id, "status": HANDED_OVER, "handed_over_at": _now_iso(),
             "evidence": evidence}
    tmp = pending_path.with_suffix(".pending.tmp")
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(state, fh, indent=2)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, pending_path)
    record_event(msg_id, HANDED_OVER, evidence=evidence)


def awaiting_handover() -> list[str]:
    """Flagged messages not yet handed over to the agent."""
    return [m for m in list_pending_messages() if not is_message_handed_over(m)]


def is_message_handed_over(msg_id: str) -> bool:
    """Check if a message was already handed over to the agent."""
    pending_path = _pending_path(msg_id)
    if not pending_path.exists():
        return False
    try:
        with open(pending_path, encoding="utf-8") as fh:
            state = json.load(fh)
            return state.get("status") == HANDED_OVER
    except (OSError, json.JSONDecodeError):
        return False
