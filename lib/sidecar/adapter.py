"""arc-011 sidecar adapter — integrate receiver with Claude Code hooks.

T-3561 (arc-011 slice 1). Bridges the receiver process with Claude Code's
Stop and UserPromptSubmit hooks for safe, agent-controlled injection.

Design (from T-3397):
  - Stop hook: runs at the END of a turn when the agent is idle and awaiting
    input. Sets ready-for-input: true to signal the harness is at a safe boundary.
  - UserPromptSubmit hook: runs at the START of the next turn when a human
    submits a prompt. Clears ready-for-input: false and surfaces any pending
    messages from the receiver.

This is the runtime adapter — the only part that makes a message *arrive*
in an agent's working session. Injection grants attention, never authority
(peer content is untrusted data, per T-3558).

Ready flag file: .context/sidecar/ready-for-input.yaml
The hook entry points are lib/sidecar/hooks.py (T-3693).
"""

from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path


def _sidecar_dir() -> Path:
    """Root directory for sidecar state."""
    from . import receiver
    d = receiver._root() / ".context" / "sidecar"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _ready_flag_path() -> Path:
    """Path to the agent's ready-for-input flag."""
    return _sidecar_dir() / "ready-for-input.yaml"


def set_ready_for_input(ready: bool) -> None:
    """Mark the agent as ready to receive injected input (Stop hook).

    Called by agents/context/stop-driver.sh at the END of a turn,
    when the harness is genuinely idle and safe to inject into.
    """
    path = _ready_flag_path()
    state = {
        "ready": ready,
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "pid": os.getpid(),
    }
    # Atomic replace, deliberately WITHOUT fsync (T-3693): this runs first in
    # every UserPromptSubmit, and an fsync stalled 30 s+ under btrfs load, long
    # enough for Claude Code to kill the hook and discard its output. The flag
    # is advisory state, not a durable record: a crash that loses it reads as
    # "not ready", which is the safe direction.
    tmp = path.with_suffix(f".yaml.{os.getpid()}.tmp")
    try:
        tmp.write_text(f"# Ready for input: {ready}\n"
                       f"ready: {str(ready).lower()}\n"
                       f"updated_at: {state['updated_at']}\n"
                       f"pid: {state['pid']}\n", encoding="utf-8")
        os.replace(tmp, path)
    except OSError:
        pass  # Best effort; do not block the hook


def is_ready_for_input() -> bool:
    """Check if the agent is ready to receive input.

    True only if the flag file exists and says ready: true. Missing or
    unreadable reads as NOT ready — the safe direction (T-3397:109): a message
    waits rather than being typed into a mid-turn agent. The flag is set by
    the Stop hook and cleared by the UserPromptSubmit hook and by the injector
    itself just before it types.
    """
    path = _ready_flag_path()
    if not path.exists():
        return False

    try:
        content = path.read_text(encoding="utf-8")
        # Simple line-based parsing of the YAML file
        for line in content.splitlines():
            if line.startswith("ready:"):
                value = line.split(":", 1)[1].strip().lower()
                return value in ("true", "yes")
    except OSError:
        return False

    return False


def clear_ready_for_input() -> None:
    """Clear the ready-for-input flag (UserPromptSubmit hook).

    Called when a human submits a new prompt, to signal that we are no longer
    idle and safe to inject. This MUST run before surfacing messages, with
    zero tolerance for lag — the agent is about to start work.
    """
    set_ready_for_input(False)


def get_pending_messages(limit: int = 100) -> list[dict]:
    """Get pending messages from the receiver to surface to the agent.

    Called by UserPromptSubmit hook to inject into the next turn's prompt.
    This is a PEEK operation — messages are returned but their state is
    not advanced (no HANDED_OVER recorded yet). The receiver process
    tracks injection separately.
    """
    from . import receiver

    messages = []
    for msg_id in receiver.list_pending_messages()[:limit]:
        msg = receiver.read_message(msg_id)
        if msg and not receiver.is_message_handed_over(msg_id):
            messages.append({
                "msg_id": msg_id,
                "from": msg.get("from"),
                "conversation_id": msg.get("conversation_id"),
                "body": msg.get("body"),
                "created_at": msg.get("created_at"),
            })

    return messages
