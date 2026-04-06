"""ClaudeCodeAdapter — Claude Code agent sessions via PTY (T-967).

Spawns `claude -p "prompt"` or `claude -c` (interactive) via PTY.
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


class ClaudeCodeAdapter:
    """Claude Code session via PTY-wrapped CLI."""

    name = "claude"

    def spawn(self, config: dict) -> dict:
        """Spawn a Claude Code session.

        Config keys:
            prompt: Prompt for -p mode (if omitted, uses -c for interactive)
            cwd: Working directory (default: PROJECT_ROOT or cwd)
            model: Model to use (optional, e.g. "opus")
            env: Extra environment variables
            output_format: Output format for -p mode (default: "text")
        """
        prompt = config.get("prompt")
        cwd = config.get("cwd", os.environ.get("PROJECT_ROOT", os.getcwd()))
        model = config.get("model")
        extra_env = config.get("env", {})
        output_format = config.get("output_format", "text")

        cmd = ["claude"]
        if prompt:
            cmd += ["-p", prompt, "--output-format", output_format]
        else:
            cmd += ["-c"]  # Interactive/continue mode

        if model:
            cmd += ["--model", model]

        master_fd, slave_fd = pty.openpty()
        child_pid = os.fork()

        if child_pid == 0:
            # Child process
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
            # T-576: Unset CLAUDECODE to allow nested sessions
            env.pop("CLAUDECODE", None)
            env.update(extra_env)
            os.chdir(cwd)
            os.execvp(cmd[0], cmd)
        else:
            # Parent process
            os.close(slave_fd)
            flags = fcntl.fcntl(master_fd, fcntl.F_GETFL)
            fcntl.fcntl(master_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
            logger.info("Spawned Claude Code: pid=%d, fd=%d, cmd=%s", child_pid, master_fd, " ".join(cmd))
            return {"pid": child_pid, "fd": master_fd, "cmd": cmd}

    def capabilities(self) -> dict:
        return {
            "mode": "read-write",
            "file_edit": True,
            "tool_use": True,
            "streaming": True,
            "context_window": 300000,
            "persistent_thread": False,
        }

    def inject(self, handle: dict, data: bytes) -> None:
        fd = handle.get("fd")
        if fd is None:
            return
        try:
            os.write(fd, data)
        except OSError:
            logger.warning("Failed to write to Claude PTY fd=%d", fd)

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
            logger.warning("Failed to resize Claude PTY fd=%d", fd)

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
            logger.info("Killed Claude Code session: pid=%d", pid)

    def get_cost(self, handle: dict) -> Optional[dict]:
        # Token tracking for Claude Code sessions requires reading
        # the session transcript JSONL. For now, return empty cost
        # stub — real implementation will integrate with lib/costs.sh.
        return {
            "input_tokens": 0,
            "output_tokens": 0,
            "cache_read_tokens": 0,
            "cache_write_tokens": 0,
            "total_tokens": 0,
            "model": "claude-opus-4-6",
        }

    def is_alive(self, handle: dict) -> bool:
        pid = handle.get("pid")
        if pid is None:
            return False
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False
