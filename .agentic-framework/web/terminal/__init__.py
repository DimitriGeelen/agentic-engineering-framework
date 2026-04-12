"""Terminal PTY manager for Watchtower web terminal (T-964, T-967).

Manages PTY processes and bridges them to Flask-SocketIO WebSocket connections.
Refactored to use provider adapters (T-967) while preserving the same public API.

NOTE: This was originally web/terminal.py. When web/terminal/ package was
created (T-967), Python's package resolution shadows the .py file. All PTY
management code lives here in __init__.py to maintain backward compatibility
with `from web import terminal as term_mgr` imports.
"""

import logging

from web.terminal.adapters.local_shell import LocalShellAdapter

logger = logging.getLogger(__name__)

# Singleton adapter for backward compatibility
_adapter = LocalShellAdapter()

# Active PTY sessions: {sid: {"fd": int, "pid": int}}
_sessions = {}


def spawn_pty(sid, shell="/bin/bash"):
    """Spawn a new PTY process and register it for the given SocketIO session ID."""
    if sid in _sessions:
        logger.warning("Session %s already has a PTY, closing old one", sid)
        kill_pty(sid)

    handle = _adapter.spawn({"shell": shell})
    _sessions[sid] = handle
    logger.info("Spawned PTY for session %s: pid=%d, fd=%d", sid, handle["pid"], handle["fd"])
    return handle["fd"], handle["pid"]


def read_pty(sid, max_bytes=65536):
    """Read available output from the PTY. Returns bytes or None."""
    handle = _sessions.get(sid)
    if not handle:
        return None
    return _adapter.read(handle, max_bytes)


def write_pty(sid, data):
    """Write input data to the PTY."""
    handle = _sessions.get(sid)
    if not handle:
        return
    if isinstance(data, str):
        data = data.encode("utf-8")
    _adapter.inject(handle, data)


def resize_pty(sid, rows, cols):
    """Resize the PTY to the given dimensions."""
    handle = _sessions.get(sid)
    if not handle:
        return
    _adapter.resize(handle, rows, cols)


def kill_pty(sid):
    """Kill the PTY process and clean up."""
    handle = _sessions.pop(sid, None)
    if not handle:
        return
    _adapter.kill(handle)
    logger.info("Killed PTY for session %s", sid)


def has_pty(sid):
    """Check if a PTY exists for the given session ID."""
    return sid in _sessions


# --- TermLink observation sessions (T-966) ---

# TermLink-attached sessions: {sid: {"tl_name": str, "last_lines": int}}
_termlink_sessions = {}


def attach_termlink(sid, tl_name):
    """Register a TermLink observation session."""
    _termlink_sessions[sid] = {"tl_name": tl_name, "last_lines": 0}
    logger.info("Attached TermLink session %s → %s", sid, tl_name)


def read_termlink(sid, max_lines=50):
    """Poll TermLink PTY output for an observation session. Returns string or None."""
    tl = _termlink_sessions.get(sid)
    if not tl:
        return None
    try:
        import subprocess
        result = subprocess.run(
            ["termlink", "pty", "output", tl["tl_name"],
             "--lines", str(max_lines), "--strip-ansi"],
            capture_output=True, text=True, timeout=2,
        )
        if result.returncode == 0:
            output = result.stdout
            # Only return new content (simple approach: hash comparison)
            if output and hash(output) != tl.get("last_hash"):
                tl["last_hash"] = hash(output)
                return output
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return None


def write_termlink(sid, data):
    """Inject input to a TermLink session."""
    tl = _termlink_sessions.get(sid)
    if not tl:
        return
    try:
        import subprocess
        subprocess.run(
            ["termlink", "pty", "inject", tl["tl_name"], data, "--enter"],
            capture_output=True, timeout=2,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        logger.warning("Failed to inject to TermLink session %s", tl["tl_name"])


def detach_termlink(sid):
    """Remove a TermLink observation session."""
    tl = _termlink_sessions.pop(sid, None)
    if tl:
        logger.info("Detached TermLink session %s", sid)


def is_termlink_session(sid):
    """Check if this is a TermLink observation session."""
    return sid in _termlink_sessions


def cleanup_all():
    """Kill all PTY sessions. Called on shutdown."""
    for sid in list(_sessions.keys()):
        kill_pty(sid)
    _termlink_sessions.clear()
