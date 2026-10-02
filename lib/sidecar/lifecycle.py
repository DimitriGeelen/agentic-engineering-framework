"""arc-011 sidecar receiver lifecycle — address, token and host registry.

T-3561 / T-3693 (arc-011 slice 1). Manages the per-agent receiver process's
durable address and credentials.

Triple-file pattern (from CLAUDE.md §Watchtower Port):
  .context/sidecar/receiver.pid     — process ID
  .context/sidecar/receiver.port    — listening port
  .context/sidecar/receiver.url     — full URL (http://127.0.0.1:PORT)
  .context/sidecar/receiver.token   — bearer token, mode 0600 (T-3475: the
                                      token exists BEFORE the port opens)

Read these, never guess the port.

Host registry (T-3693): a sender addresses a peer by name, not by port, so a
started receiver also writes
  $FW_SIDECAR_REGISTRY_DIR/<agent>.json   (default ~/.local/state/fw-sidecar/receivers)
holding {agent, url, pid, project_root, token_file}. The token itself is never
copied into the registry; a same-host sender reads it from token_file, which
only the same user can. Cross-host addressing is T-3688.
"""

from __future__ import annotations

import json
import os
import secrets
import socket
import urllib.request
from pathlib import Path

from . import receiver


def _sidecar_dir() -> Path:
    d = receiver._root() / ".context" / "sidecar"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _triple_file_path(suffix: str) -> Path:
    return _sidecar_dir() / f"receiver.{suffix}"


def token_path() -> Path:
    return _triple_file_path("token")


def config_path() -> Path:
    return _sidecar_dir() / "receiver" / "config.json"


def find_free_port(start: int = 9000) -> int:
    """Find an available localhost port."""
    for port in range(start, start + 1000):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(("127.0.0.1", port))
                return port
        except OSError:
            continue
    raise RuntimeError("Could not find available port")


# ── token ───────────────────────────────────────────────────────────────────

def write_token() -> str:
    """Generate a fresh token and write it 0600 (created with that mode, so it
    is never world-readable even for an instant). Returns the token."""
    token = secrets.token_hex(32)
    path = token_path()
    tmp = path.with_suffix(".token.tmp")
    try:
        tmp.unlink()
    except FileNotFoundError:
        pass
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(token)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, path)
    os.chmod(path, 0o600)
    _ensure_runtime_ignored(path.parent)
    return token


#: T-3725: runtime files beside the token that must never reach git. Written by
#: the receiver itself so every project (vendored consumers included) is covered,
#: not only repos whose root .gitignore happens to list them.
_RUNTIME_IGNORES = ("receiver.token", "receiver.token.tmp", "ready-for-input.yaml", "receiver/")


def _ensure_runtime_ignored(sidecar_dir: Path) -> None:
    gi = sidecar_dir / ".gitignore"
    have = set()
    if gi.exists():
        have = {ln.strip() for ln in gi.read_text(encoding="utf-8").splitlines()}
    missing = [e for e in _RUNTIME_IGNORES if e not in have]
    if not missing:
        return
    with open(gi, "a", encoding="utf-8") as fh:
        if not have:
            fh.write("# T-3725: sidecar receiver runtime state; the token is a secret\n")
        for e in missing:
            fh.write(e + "\n")


def read_token(path: Path | None = None) -> str | None:
    path = path or token_path()
    try:
        token = path.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    return token or None


# ── config ──────────────────────────────────────────────────────────────────

def write_config(inject: bool) -> None:
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"inject": bool(inject)}), encoding="utf-8")


def inject_enabled() -> bool:
    """Injection is on unless the receiver was started with --no-inject."""
    try:
        return bool(json.loads(config_path().read_text(encoding="utf-8")).get("inject", True))
    except (OSError, json.JSONDecodeError):
        return True


# ── triple-file ─────────────────────────────────────────────────────────────

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


def pid_alive(pid) -> bool:
    if not pid or not isinstance(pid, int):
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def is_receiver_alive(info: dict) -> bool:
    """Check if the receiver process is still running."""
    return pid_alive(info.get("pid"))


def health(url: str, timeout: float = 2.0) -> bool:
    try:
        with urllib.request.urlopen(f"{url}/health", timeout=timeout) as resp:
            return resp.status == 200 and json.loads(resp.read()).get("status") == "ok"
    except Exception:
        return False


def clear_triple_file() -> None:
    """Remove the triple files (process shutdown). The token stays: it is
    regenerated by the next start, and removing it here would race a
    concurrent start."""
    for suffix in ("pid", "port", "url"):
        try:
            _triple_file_path(suffix).unlink()
        except FileNotFoundError:
            pass


def get_receiver_url() -> str | None:
    """Get the receiver's URL from the triple file, or None if not running."""
    info = read_triple_file()
    if not info or not is_receiver_alive(info):
        return None
    url = info.get("url")
    return url if isinstance(url, str) else None


# ── host registry ───────────────────────────────────────────────────────────

def registry_dir() -> Path:
    env = os.environ.get("FW_SIDECAR_REGISTRY_DIR")
    if env:
        d = Path(env)
    else:
        base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
        d = Path(base) / "fw-sidecar" / "receivers"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _registry_file(agent: str) -> Path:
    safe = "".join(c if c.isalnum() or c in "._-" else "_" for c in agent)
    return registry_dir() / f"{safe}.json"


def register(agent: str, url: str, pid: int) -> Path:
    entry = {
        "agent": agent,
        "url": url,
        "pid": pid,
        "project_root": str(receiver._root().resolve()),
        "token_file": str(token_path().resolve()),
    }
    path = _registry_file(agent)
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(entry), encoding="utf-8")
    os.replace(tmp, path)
    return path


def unregister(agent: str, pid: int | None = None) -> None:
    """Remove our registry entry — only if it is still ours (a newer receiver
    for the same agent name must not be unregistered by a stale stop)."""
    path = _registry_file(agent)
    try:
        entry = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return
    if pid is None or entry.get("pid") == pid:
        try:
            path.unlink()
        except FileNotFoundError:
            pass


def lookup(agent: str) -> dict | None:
    """The registry entry for `agent`, or None if no receiver ever registered.

    The entry carries `live` (pid running AND /health answering). A
    registered-but-dead receiver is returned with live=False rather than as
    None: the sender then spends its retry budget and records UNDELIVERABLE
    ("receiver down"), instead of silently rerouting to the hub as though the
    peer had never had a receiver. A lookup is a read; nothing is deleted.
    """
    if not agent:
        return None
    name = agent.rstrip("/").rsplit("/", 1)[-1]
    try:
        entry = json.loads(_registry_file(name).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    entry["live"] = pid_alive(entry.get("pid")) and health(entry.get("url", ""))
    return entry
