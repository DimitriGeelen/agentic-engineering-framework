"""arc-011 sidecar receiver — HTTP API for receiving peer consults.

T-3561 (arc-011 slice 1). A durable, per-agent HTTP server that receives
messages durably and confirms receipt. This is the keystone: every other
slice depends on a process that exists.

Architecture:
  - Runs as a separate process per agent, with a stable HTTP address
  - Stores messages durably in .context/sidecar/inbox/<msg_id>.json
  - Sets a dirty-bit flag AFTER successful message write
  - Returns RECEIVED immediately (sender-side confirmation)
  - Injects via Stop hook (ready-for-input flag) and UserPromptSubmit hook
  - Returns HANDED_OVER when agent is ready and message is delivered
  - Authenticated: only recognized callers can send

Per D-645 §2 (round trip):
  - Step 3: store message locally, atomic with flag
  - Step 4: set flag file (dirty-bit)
  - Step 5: CONFIRM-1 "received" → sender's API
  - Step 7-9: tick → ready check → inject → CONFIRM-2 "handed over"

Message storage layout:
  .context/sidecar/receiver/
    messages/<msg_id>.json     — message envelope (durable)
    messages/<msg_id>.ready    — dirty-bit flag (receiver-side)
    liveness.yaml              — self-probe data
    bound.yaml                 — pid/port/url triple-file
"""

from __future__ import annotations

import json
import os
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


def store_message(msg_id: str, envelope: dict) -> tuple[bool, str]:
    """Store a message durably and atomically set the ready flag.

    Returns (success, error_msg). On success, the message file and flag
    are both written and the caller can return RECEIVED to the sender.
    """
    # Validate message ID is stable (not regenerated from content)
    if not msg_id or not isinstance(msg_id, str):
        return False, "Invalid message ID"

    # Check for duplicate: if both message and ready flag exist, this is a retry
    msg_path = _message_path(msg_id)
    ready_path = _ready_flag_path(msg_id)

    if msg_path.exists() and ready_path.exists():
        # Message was already stored; this is a retry of the same ID
        # Re-storing is idempotent — return success without rewriting
        return True, ""

    if msg_path.exists() and not ready_path.exists():
        # Torn write: message exists but flag doesn't. Shouldn't happen in normal flow
        # but we treat it as a retry that already failed
        return False, "Message partially stored (flag missing); retry with new ID"

    # Write message to temp path first
    tmp_path = msg_path.with_suffix(".json.tmp")
    try:
        with open(tmp_path, "w", encoding="utf-8") as fh:
            json.dump(envelope, fh, indent=2)
            fh.flush()
            os.fsync(fh.fileno())
        # Atomic rename
        os.replace(tmp_path, msg_path)
    except (OSError, IOError) as e:
        if tmp_path.exists():
            try:
                tmp_path.unlink()
            except OSError:
                pass
        return False, f"Failed to write message: {e}"

    # NOW write the flag (dirty-bit) to signal the message is ready
    # This ordering is critical: if interrupted here, we have orphaned message,
    # not a flag with no message
    try:
        with open(ready_path, "w", encoding="utf-8") as fh:
            fh.write("")  # Empty flag file
            fh.flush()
            os.fsync(fh.fileno())
    except (OSError, IOError) as e:
        return False, f"Failed to write ready flag: {e}"

    return True, ""


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


def mark_handed_over(msg_id: str) -> None:
    """Record that a message was handed over to the agent (injected into prompt)."""
    pending_path = _pending_path(msg_id)
    pending_path.parent.mkdir(parents=True, exist_ok=True)
    state = {"msg_id": msg_id, "status": HANDED_OVER, "handed_over_at": _now_iso()}
    try:
        with open(pending_path, "w", encoding="utf-8") as fh:
            json.dump(state, fh, indent=2)
            fh.flush()
            os.fsync(fh.fileno())
    except OSError:
        pass  # Best effort


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
