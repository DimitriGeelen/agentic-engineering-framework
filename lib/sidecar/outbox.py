"""arc-011 sidecar — same-host outbox message/flag/ack substrate.

T-3402 (T-3397 Amendment 5, slice 1). Implements the file shapes and the
three-state ack ledger specified in
docs/reports/T-3396-peer-consult-sidecar-inception.md — same-host only
(hub=None). Cross-host transport, the liveness self-probe daemon, and the
Stop/UserPromptSubmit hook wiring for the ready-flag are separate follow-on
slices, not this module's concern.

File shapes (Amendment 5):
    .context/sidecar/outbox/<client_msg_id>.json   — the message itself
    .context/sidecar/outbox/<client_msg_id>.flag   — durability dirty-bit,
        written only after the message file's write is complete, so the
        flag's existence IS the durability signal
    .context/sidecar/awaiting-ack.jsonl            — append-only ack ledger

Ack states: STORED (non-terminal — the only state that can expire) ->
HUB_ACCEPTED | INJECTED_LATER | UNKNOWN (all terminal).

Per T-3561 AC10: INJECTED_NOW renamed HUB_ACCEPTED. The hub accepted the
message; this is NOT the same as "injected into the agent" (T-3397, AC5).
See INJECTED_LATER for delivery after store-and-wait.
"""

from __future__ import annotations

import json
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

STORED = "STORED"
HUB_ACCEPTED = "HUB_ACCEPTED"  # T-3561: renamed from INJECTED_NOW
INJECTED_NOW = "HUB_ACCEPTED"  # Alias for backward compatibility during migration
# T-3717: the alias above renames the Python NAME only. Ledger rows written
# before T-3561 still carry the literal string "INJECTED_NOW" on disk, and the
# ledger is append-only, so they never go away. `_read_ledger` maps this value
# to HUB_ACCEPTED so every reader (status counts, retry eligibility) still sees
# those rows as delivered rather than as an unknown, retryable state.
LEGACY_INJECTED_NOW = "INJECTED_NOW"
INJECTED_LATER = "INJECTED_LATER"
UNKNOWN = "UNKNOWN"
TERMINAL_STATES = frozenset({HUB_ACCEPTED, INJECTED_LATER, UNKNOWN})


def _framework_root() -> Path:
    """Where the framework code lives (`<project>/.agentic-framework` when vendored)."""
    env = os.environ.get("FRAMEWORK_ROOT")
    if env:
        return Path(env)
    return Path(__file__).resolve().parents[2]


def _is_project_root(d: Path) -> bool:
    return (d / ".framework.yaml").is_file() or (
        (d / "FRAMEWORK.md").is_file() and (d / "bin" / "fw").is_file())


def _root() -> Path:
    """The CONSUMER project root: sidecar state and identity live here, never in
    the vendored `.agentic-framework` dir (T-3671). PROJECT_ROOT, else the
    nearest ancestor of cwd holding `.framework.yaml` (or the framework repo
    itself), else the framework root with a vendored `.agentic-framework`
    stripped."""
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


def _outbox_dir() -> Path:
    d = _root() / ".context" / "sidecar" / "outbox"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _ledger_path() -> Path:
    p = _root() / ".context" / "sidecar" / "awaiting-ack.jsonl"
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_message(from_id: str, to: str, body: str, conversation_id: str,
                   urgent: bool = False, hub: str | None = None,
                   in_reply_to: str | None = None) -> str:
    """Write a message file, then its flag file. Returns client_msg_id.

    Ordering is the whole point: the message file is written to a temp path
    and atomically renamed into place BEFORE the flag file is created, so a
    reader that observes the flag is guaranteed the message file is fully
    written and readable — a torn write can only ever produce an orphaned
    message file with no flag, never a flag pointing at incomplete content.
    """
    client_msg_id = str(uuid.uuid4())
    outbox = _outbox_dir()
    # T-3782: the waiting register's outbound cut-off exists before any send.
    # Fail-closed: no cut-off, no send (a message sent before a cut-off that
    # is written later would be invisible forever — codex round 2).
    from . import waiting
    waiting.epoch()
    msg = {
        "client_msg_id": client_msg_id,
        "from": from_id,
        "to": to,
        "hub": hub,
        "conversation_id": conversation_id,
        "urgent": urgent,
        "body": body,
        "created_at": _now_iso(),
    }
    if in_reply_to:
        # T-3804: the id this answers, so the original sender's retry sweep
        # can settle it by id (transport carries it as in_reply_to_msg_id).
        msg["in_reply_to"] = in_reply_to

    msg_path = outbox / f"{client_msg_id}.json"
    tmp_path = outbox / f"{client_msg_id}.json.tmp"
    with open(tmp_path, "w", encoding="utf-8") as fh:
        json.dump(msg, fh)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp_path, msg_path)  # atomic on same filesystem

    flag_path = outbox / f"{client_msg_id}.flag"
    with open(flag_path, "w", encoding="utf-8"):
        pass

    return client_msg_id


def list_pending() -> list[str]:
    """Return client_msg_ids with BOTH a message file and a flag file.

    A message file with no flag is a torn/in-progress write and must not be
    surfaced as pending.
    """
    outbox = _outbox_dir()
    flagged = {p.stem for p in outbox.glob("*.flag")}
    messaged = {p.stem for p in outbox.glob("*.json")}
    return sorted(flagged & messaged)


def record_ack(client_msg_id: str, target: str, hub: str | None,
               state: str, deadline: str | None = None,
               error: str | None = None, attempts: int | None = None,
               next_retry_at: str | None = None,
               rung: int | None = None) -> None:
    """Append one row to the ack ledger. Append-only — never rewritten.

    `error` annotates a row without changing its state, so a failed delivery
    attempt is recorded while the message stays non-terminal and retryable
    (T-3404). It does not add a fourth state to the three-state machine.

    `attempts` / `next_retry_at` / `rung` carry the message's position on the
    universal retry ladder (T-3434, D-600). They are ledger DATA, not ledger
    STATE: the three-state machine is untouched, and a row written without
    them (every row this ledger held before T-3434) reads back as a message
    that has had one attempt and no scheduled retry — which is exactly what
    those rows were.
    """
    row = {
        "client_msg_id": client_msg_id,
        "target": target,
        "hub": hub,
        "state": state,
        "deadline": deadline,
        "error": error,
        "attempts": attempts,
        "next_retry_at": next_retry_at,
        "rung": rung,
        "ts": _now_iso(),
    }
    with open(_ledger_path(), "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row) + "\n")


def _read_ledger() -> list[dict]:
    path = _ledger_path()
    if not path.exists():
        return []
    rows = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(row, dict) and row.get("state") == LEGACY_INJECTED_NOW:
                row["state"] = HUB_ACCEPTED
            rows.append(row)
    return rows


def latest_ack_state(client_msg_id: str) -> dict | None:
    """Return the most recently written ledger row for this id, or None."""
    matches = [r for r in _read_ledger() if r.get("client_msg_id") == client_msg_id]
    if not matches:
        return None
    return matches[-1]


def resolve_expired(now: str | None = None) -> list[str]:
    """Flip any past-deadline STORED row to UNKNOWN. Returns the ids flipped.

    Only STORED is non-terminal — INJECTED_NOW/INJECTED_LATER/UNKNOWN are
    already terminal and are left untouched regardless of their deadline.
    """
    now_dt = datetime.fromisoformat(now) if now else datetime.now(timezone.utc)

    latest_by_id: dict[str, dict] = {}
    for row in _read_ledger():
        latest_by_id[row["client_msg_id"]] = row

    flipped = []
    for client_msg_id, row in latest_by_id.items():
        if row.get("state") != STORED:
            continue
        deadline = row.get("deadline")
        if not deadline:
            continue
        deadline_dt = datetime.fromisoformat(deadline)
        if now_dt > deadline_dt:
            record_ack(client_msg_id, row.get("target"), row.get("hub"), UNKNOWN)
            flipped.append(client_msg_id)
    return flipped
