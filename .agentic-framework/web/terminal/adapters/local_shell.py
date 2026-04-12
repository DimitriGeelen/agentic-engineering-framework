"""LocalShellAdapter — local shell sessions via PTY (T-967).

Migrated from web/terminal.py's direct pty management into the adapter pattern.
Design: docs/reports/T-962-v7-orchestrator-design.md §4.3.
"""

import fcntl
import logging
import os
import pty
import select
import signal
import struct
import termios
from typing import Optional

logger = logging.getLogger(__name__)


class LocalShellAdapter:
    """Local shell session via PTY fork."""

    name = "local"

    def spawn(self, config: dict) -> dict:
        """Spawn a shell PTY.

        Config keys:
            shell: Shell binary (default: $SHELL or /bin/bash)
            cwd: Working directory (default: PROJECT_ROOT or cwd)
            env: Extra environment variables
        """
        shell = config.get("shell", os.environ.get("SHELL", "/bin/bash"))
        cwd = config.get("cwd", os.environ.get("PROJECT_ROOT", os.getcwd()))
        extra_env = config.get("env", {})

        master_fd, slave_fd = pty.openpty()
        child_pid = os.fork()

        if child_pid == 0:
            # Child process — become the shell
            os.close(master_fd)
            os.setsid()
            fcntl.ioctl(slave_fd, termios.TIOCSCTTY, 0)
            os.dup2(slave_fd, 0)
            os.dup2(slave_fd, 1)
            os.dup2(slave_fd, 2)
            if slave_fd > 2:
                os.close(slave_fd)
            env = os.environ.copy()
            env["TERM"] = "xterm-256color"
            env.update(extra_env)
            os.chdir(cwd)
            os.execvpe(shell, [shell], env)
        else:
            # Parent process — keep the master fd
            os.close(slave_fd)
            flags = fcntl.fcntl(master_fd, fcntl.F_GETFL)
            fcntl.fcntl(master_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
            logger.info("Spawned local shell: pid=%d, fd=%d, shell=%s", child_pid, master_fd, shell)
            return {"pid": child_pid, "fd": master_fd}

    def capabilities(self) -> dict:
        return {
            "mode": "read-write",
            "file_edit": True,
            "tool_use": False,
            "streaming": True,
            "context_window": None,
            "persistent_thread": False,
        }

    def inject(self, handle: dict, data: bytes) -> None:
        fd = handle.get("fd")
        if fd is None:
            return
        try:
            os.write(fd, data)
        except OSError:
            logger.warning("Failed to write to PTY fd=%d", fd)

    def read(self, handle: dict, max_bytes: int = 65536) -> Optional[bytes]:
        fd = handle.get("fd")
        if fd is None:
            return None
        try:
            ready, _, _ = select.select([fd], [], [], 0)
            if ready:
                return os.read(fd, max_bytes)
        except (OSError, ValueError):
            return None
        return b""

    def resize(self, handle: dict, rows: int, cols: int) -> None:
        fd = handle.get("fd")
        if fd is None:
            return
        try:
            winsize = struct.pack("HHHH", rows, cols, 0, 0)
            fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)
        except OSError:
            logger.warning("Failed to resize PTY fd=%d", fd)

    def kill(self, handle: dict) -> None:
        fd = handle.get("fd")
        pid = handle.get("pid")
        if fd is not None:
            try:
                os.close(fd)
            except OSError:
                pass
        if pid is not None:
            try:
                os.kill(pid, signal.SIGTERM)
                os.waitpid(pid, os.WNOHANG)
            except (OSError, ChildProcessError):
                pass
            logger.info("Killed local shell: pid=%d", pid)

    def get_cost(self, handle: dict) -> Optional[dict]:
        return None  # Local shells have no token cost

    def is_alive(self, handle: dict) -> bool:
        pid = handle.get("pid")
        if pid is None:
            return False
        try:
            os.kill(pid, 0)  # Signal 0 = check existence
            return True
        except OSError:
            return False
