"""arc-011 sidecar receiver lifecycle — start/stop/monitor the HTTP server.

T-3561 (arc-011 slice 1). Manages the per-agent receiver process: bind to
an available localhost port, write the triple-file (pid/port/url), maintain
liveness.

Triple-file pattern (from CLAUDE.md §Watchtower Port):
  .context/sidecar/receiver.pid     — process ID
  .context/sidecar/receiver.port    — listening port
  .context/sidecar/receiver.url     — full URL (http://localhost:PORT)

Read this, never guess the port. Consumers verify the file exists before
connecting.
"""

from __future__ import annotations

import os
import socket
from pathlib import Path


def _receiver_dir() -> Path:
    """Root directory for receiver state."""
    env = os.environ.get("PROJECT_ROOT")
    if env:
        root = Path(env)
    else:
        root = Path.cwd()
    d = root / ".context" / "sidecar" / "receiver"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _triple_file_path(suffix: str) -> Path:
    """Path to one of the triple-file components."""
    return _receiver_dir().parent / f"receiver.{suffix}"


def find_free_port(start: int = 9000) -> int:
    """Find an available localhost port."""
    for port in range(start, start + 1000):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(("127.0.0.1", port))
                s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                return port
        except OSError:
            continue
    raise RuntimeError("Could not find available port")


def write_triple_file(pid: int, port: int, url: str) -> None:
    """Write the pid/port/url triple files."""
    _triple_file_path("pid").write_text(str(pid), encoding="utf-8")
    _triple_file_path("port").write_text(str(port), encoding="utf-8")
    _triple_file_path("url").write_text(url, encoding="utf-8")


def read_triple_file() -> dict[str, str | int] | None:
    """Read the pid/port/url triple files. Returns None if incomplete."""
    pid_path = _triple_file_path("pid")
    port_path = _triple_file_path("port")
    url_path = _triple_file_path("url")

    if not (pid_path.exists() and port_path.exists() and url_path.exists()):
        return None

    try:
        pid = int(pid_path.read_text(encoding="utf-8").strip())
        port = int(port_path.read_text(encoding="utf-8").strip())
        url = url_path.read_text(encoding="utf-8").strip()
        return {"pid": pid, "port": port, "url": url}
    except (ValueError, OSError):
        return None


def is_receiver_alive(info: dict) -> bool:
    """Check if the receiver process is still running."""
    pid = info.get("pid")
    if not pid or not isinstance(pid, int):
        return False
    try:
        # On Unix, os.kill with signal 0 checks if process exists
        # On Windows, this raises except if process doesn't exist
        if os.name == "posix":
            os.kill(pid, 0)
            return True
        else:
            # Windows check
            import subprocess as sp
            result = sp.run(
                ["tasklist", "/FI", f"PID eq {pid}"],
                capture_output=True, text=True, timeout=2
            )
            return result.returncode == 0
    except (OSError, Exception):
        return False


def clear_triple_file() -> None:
    """Remove the triple files (process shutdown)."""
    for suffix in ("pid", "port", "url"):
        path = _triple_file_path(suffix)
        if path.exists():
            try:
                path.unlink()
            except OSError:
                pass


def get_receiver_url() -> str | None:
    """Get the receiver's URL from the triple file, or None if not running."""
    info = read_triple_file()
    if not info:
        return None
    if not is_receiver_alive(info):
        clear_triple_file()
        return None
    url = info.get("url")
    return url if isinstance(url, str) else None
