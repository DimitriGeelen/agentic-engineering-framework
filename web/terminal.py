"""Terminal PTY manager for Watchtower web terminal (T-964).

Manages PTY processes and bridges them to Flask-SocketIO WebSocket connections.
Based on pyxtermjs pattern, extended for multi-session support (T-965 future).
"""

import fcntl
import logging
import os
import pty
import select
import signal
import struct
import termios

logger = logging.getLogger(__name__)

# Active PTY sessions: {sid: {"fd": int, "pid": int}}
_sessions = {}


def spawn_pty(sid, shell="/bin/bash"):
    """Spawn a new PTY process and register it for the given SocketIO session ID."""
    if sid in _sessions:
        logger.warning("Session %s already has a PTY, closing old one", sid)
        kill_pty(sid)

    pid, fd = pty.openpty()
    child_pid = os.fork()

    if child_pid == 0:
        # Child process — become the shell
        os.close(pid)  # Close master in child
        os.setsid()
        # Set the slave as controlling terminal
        import fcntl as _fcntl
        _fcntl.ioctl(fd, termios.TIOCSCTTY, 0)
        # Redirect stdin/stdout/stderr to the slave PTY
        os.dup2(fd, 0)
        os.dup2(fd, 1)
        os.dup2(fd, 2)
        if fd > 2:
            os.close(fd)
        # Set TERM for color support
        env = os.environ.copy()
        env["TERM"] = "xterm-256color"
        os.execvpe(shell, [shell], env)
    else:
        # Parent process — keep the master fd
        os.close(fd)  # Close slave in parent
        _sessions[sid] = {"fd": pid, "pid": child_pid}
        # Set non-blocking
        flags = fcntl.fcntl(pid, fcntl.F_GETFL)
        fcntl.fcntl(pid, fcntl.F_SETFL, flags | os.O_NONBLOCK)
        logger.info("Spawned PTY for session %s: pid=%d, fd=%d", sid, child_pid, pid)
        return pid, child_pid


def read_pty(sid, max_bytes=65536):
    """Read available output from the PTY. Returns bytes or None."""
    session = _sessions.get(sid)
    if not session:
        return None
    fd = session["fd"]
    try:
        ready, _, _ = select.select([fd], [], [], 0)
        if ready:
            return os.read(fd, max_bytes)
    except (OSError, ValueError):
        # PTY closed
        return None
    return b""


def write_pty(sid, data):
    """Write input data to the PTY."""
    session = _sessions.get(sid)
    if not session:
        return
    fd = session["fd"]
    try:
        os.write(fd, data.encode("utf-8") if isinstance(data, str) else data)
    except OSError:
        logger.warning("Failed to write to PTY for session %s", sid)


def resize_pty(sid, rows, cols):
    """Resize the PTY to the given dimensions."""
    session = _sessions.get(sid)
    if not session:
        return
    fd = session["fd"]
    try:
        winsize = struct.pack("HHHH", rows, cols, 0, 0)
        fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)
    except OSError:
        logger.warning("Failed to resize PTY for session %s", sid)


def kill_pty(sid):
    """Kill the PTY process and clean up."""
    session = _sessions.pop(sid, None)
    if not session:
        return
    try:
        os.close(session["fd"])
    except OSError:
        pass
    try:
        os.kill(session["pid"], signal.SIGTERM)
        os.waitpid(session["pid"], os.WNOHANG)
    except (OSError, ChildProcessError):
        pass
    logger.info("Killed PTY for session %s", sid)


def has_pty(sid):
    """Check if a PTY exists for the given session ID."""
    return sid in _sessions


def cleanup_all():
    """Kill all PTY sessions. Called on shutdown."""
    for sid in list(_sessions.keys()):
        kill_pty(sid)
