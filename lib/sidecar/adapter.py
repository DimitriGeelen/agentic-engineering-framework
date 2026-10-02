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

T-3745 — readiness is per SESSION, not per project. Two Claude sessions can
share one project (a `claude-fw --termlink` fleet agent plus the operator's own
terminal, 055 @117). One project-wide flag let the operator's Stop hook mark
"ready" while the fleet agent was mid-turn, and the injector typed into the
busy one. So every Stop / UserPromptSubmit now also writes

    .context/sidecar/sessions/<claude session_id>.json
      {session_id, transcript_path, termlink_session, claude_pid, ready, updated_at}

keyed on the hook input's `session_id`, carrying the TermLink session the
hook runs inside (`TERMLINK_SESSION_ID`, which `termlink spawn` sets in the
PTY shell that `claude-fw --termlink` launches claude from). The injector
(inject.py) reads ONLY these records: it types into a TermLink session only
when that session's own record says ready. The project-wide file above is
kept as a display summary ("did any session last stop or prompt") and is not
consulted by any injection decision.
"""

from __future__ import annotations

import json
import os
import re
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


# ── per-session readiness (T-3745) ──────────────────────────────────────────

_SID_RE = re.compile(r"[^A-Za-z0-9_-]")


def _sessions_dir() -> Path:
    d = _sidecar_dir() / "sessions"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _safe_sid(session_id: str) -> str:
    return _SID_RE.sub("", str(session_id or ""))[:128]


def _session_path(session_id: str) -> Path:
    return _sessions_dir() / f"{_safe_sid(session_id)}.json"


def _claude_ancestor_pid(start: int | None = None, depth: int = 16) -> int | None:
    """The pid of the `claude` process this hook runs under, found by walking
    /proc parents. Recorded so a session whose claude has exited (its TermLink
    shell lives on under claude-fw) never reads as ready: typing into that
    shell would hand the line to bash, not to an agent."""
    pid = start or os.getpid()
    for _ in range(depth):
        try:
            stat = Path(f"/proc/{pid}/stat").read_text()
        except OSError:
            return None
        # comm is in parentheses and may hold spaces; fields after the LAST ')'.
        comm = stat[stat.find("(") + 1:stat.rfind(")")]
        if comm == "claude":
            return pid
        try:
            pid = int(stat[stat.rfind(")") + 2:].split()[1])
        except (IndexError, ValueError):
            return None
        if pid <= 1:
            return None
    return None


def session_identity(hook_input: dict) -> dict | None:
    """{session_id, transcript_path, termlink_session, claude_pid} for the
    session a hook fired in, or None when the hook input carries no
    session_id (then nothing per-session can be keyed and nothing is
    written — failing toward "not ready", the safe direction)."""
    sid = _safe_sid((hook_input or {}).get("session_id") or "")
    if not sid:
        return None
    return {
        "session_id": sid,
        "transcript_path": str((hook_input or {}).get("transcript_path") or "") or None,
        "termlink_session": os.environ.get("TERMLINK_SESSION_ID") or None,
        "claude_pid": _claude_ancestor_pid(),
    }


def set_session_ready(hook_input: dict, ready: bool) -> dict | None:
    """Write this session's own ready record (Stop: True, UserPromptSubmit:
    False). Atomic replace, no fsync — same reasoning as set_ready_for_input."""
    ident = session_identity(hook_input)
    if ident is None:
        return None
    record = dict(ident, ready=bool(ready),
                  updated_at=datetime.now(timezone.utc).isoformat())
    path = _session_path(ident["session_id"])
    tmp = path.with_suffix(f".json.{os.getpid()}.tmp")
    try:
        tmp.write_text(json.dumps(record), encoding="utf-8")
        os.replace(tmp, path)
    except OSError:
        return None
    return record


def clear_session_ready(session_id: str) -> None:
    """Mark one session busy (the injector does this before it types)."""
    path = _session_path(session_id)
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return
    record["ready"] = False
    record["updated_at"] = datetime.now(timezone.utc).isoformat()
    tmp = path.with_suffix(f".json.{os.getpid()}.tmp")
    try:
        tmp.write_text(json.dumps(record), encoding="utf-8")
        os.replace(tmp, path)
    except OSError:
        pass


def _pid_alive(pid) -> bool:
    if not isinstance(pid, int) or pid <= 1:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def session_records() -> list[dict]:
    """Every per-session record, newest first. A record whose recorded claude
    process has exited is reported with ready=False and alive=False."""
    out = []
    for p in _sessions_dir().glob("*.json"):
        try:
            rec = json.loads(p.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        pid = rec.get("claude_pid")
        rec["alive"] = _pid_alive(pid) if pid else None
        if rec["alive"] is False:
            rec["ready"] = False
        out.append(rec)
    out.sort(key=lambda r: str(r.get("updated_at") or ""), reverse=True)
    return out


def ready_sessions() -> list[dict]:
    """Sessions whose OWN record says ready, newest Stop first."""
    return [r for r in session_records() if r.get("ready") is True]
