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
Pending messages surface as additionalContext in the UserPromptSubmit hook.
"""

from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path


def _sidecar_dir() -> Path:
    """Root directory for sidecar state."""
    env = os.environ.get("PROJECT_ROOT")
    if env:
        root = Path(env)
    else:
        root = Path.cwd()
    d = root / ".context" / "sidecar"
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
    try:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(f"# Ready for input: {ready}\n")
            fh.write(f"ready: {str(ready).lower()}\n")
            fh.write(f"updated_at: {state['updated_at']}\n")
            fh.write(f"pid: {state['pid']}\n")
            fh.flush()
            os.fsync(fh.fileno())
    except OSError:
        pass  # Best effort; do not block the hook


def is_ready_for_input() -> bool:
    """Check if the agent is ready to receive input.

    Returns True only if the ready flag exists, is recent (within last 5 sec),
    and says ready=true. This conservative approach avoids injecting into a
    busy agent if the Stop hook somehow fails to clear the flag.
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
