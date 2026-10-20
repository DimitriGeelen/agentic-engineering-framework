"""arc-011 sidecar — which TermLink runtime dir `termlink` should look in (T-4482).

`termlink discover` lists the sessions registered under ONE runtime dir:
TERMLINK_RUNTIME_DIR, else termlink's per-user default. A hub registry may live
elsewhere (ring20 hosts: /var/lib/termlink). A watcher started by cron or the
supervisor inherits no TERMLINK_RUNTIME_DIR, so its discover saw the default dir,
returned no sessions, and delivery between prompts silently never happened.

Resolution, the way the hub does it: TERMLINK_RUNTIME_DIR when set; else
/var/lib/termlink when it exists; else None (termlink's own default).
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

ENV = "TERMLINK_RUNTIME_DIR"
HUB_DIR = "/var/lib/termlink"


def resolve(environ=None, hub_dir: str | None = None) -> tuple[str | None, str]:
    """(dir, source). dir None = let termlink use its default."""
    environ = os.environ if environ is None else environ
    hub_dir = hub_dir or HUB_DIR
    if environ.get(ENV):
        return environ[ENV], f"env {ENV}"
    if Path(hub_dir).is_dir():
        return hub_dir, f"{hub_dir} (present; {ENV} unset)"
    return None, "termlink default"


def env_for(runtime_dir: str | None, environ=None) -> dict:
    env = dict(os.environ if environ is None else environ)
    if runtime_dir:
        env[ENV] = runtime_dir
    return env


def apply(environ=None) -> tuple[str | None, str]:
    """Export the resolved dir into the process environment so every `termlink`
    call this process makes (discover, pty inject, channel ...) uses it."""
    environ = os.environ if environ is None else environ
    d, source = resolve(environ)
    if d:
        environ[ENV] = d
    return d, source


def other_dirs(current: str | None, hub_dir: str | None = None) -> list[str]:
    """Known runtime dirs other than `current`."""
    hub_dir = hub_dir or HUB_DIR
    return [d for d in (hub_dir,) if Path(d).is_dir() and d != current]


def sessions_in(runtime_dir: str, runner=subprocess.run) -> int:
    """How many sessions `termlink discover` finds under `runtime_dir` (0 on error)."""
    try:
        proc = runner(["termlink", "discover", "--json"], capture_output=True, text=True,
                      timeout=15, env=env_for(runtime_dir))
        if proc.returncode != 0:
            return 0
        return len(json.loads(proc.stdout).get("sessions", []))
    except (OSError, ValueError, subprocess.SubprocessError):
        return 0


def mismatch_warning(current: str | None, runner=subprocess.run) -> str | None:
    """Called when discover under `current` returned 0 sessions: the name of
    another known runtime dir that has some, as a WARN line, else None."""
    for d in other_dirs(current):
        n = sessions_in(d, runner)
        if n:
            return (f"WARN termlink discover found 0 sessions under "
                    f"{current or 'the termlink default dir'} but {d} has {n}; "
                    f"set {ENV}={d} for the sidecar watcher")
    return None
