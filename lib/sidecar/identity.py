"""The termlink signing identity every sidecar termlink call runs under (T-4311).

`lib/rail-identity.sh` (T-2904) resolves the project's own signing key from
RAIL_IDENTITY_FILE, but only `fw rail post` applied it. Every termlink call in
lib/sidecar ran with the inherited env, so sidecar mail was signed with the
host-shared key unless TERMLINK_IDENTITY_FILE happened to be exported.

termlink picks its key by ENV PRECEDENCE (PL-236):

    TERMLINK_IDENTITY_FILE > TERMLINK_AGENT_ID > TERMLINK_IDENTITY_DIR > host default

so the fix is one env, built here and installed once per sidecar process by
`apply()` at each entry point. Every `subprocess.run/Popen` in lib/sidecar
inherits os.environ (none passes a scrubbed env), so that is every termlink
call, and every child the sidecar spawns, without touching a call site.

OFF unless SIDECAR_RAIL_IDENTITY=1. Changing the signing key changes which
`dm:*` rails this project is addressed by (lib/sidecar/dm.py keys rails by
fingerprint), so adopting it is a coordination event, not a config tweak — the
same warning `rail_identity_guard` prints. While it is on, dm.py also keeps
reading the rails of the host key we moved off (SIDECAR_HOST_DM_TRANSITION,
default 1) so no DM addressed to the old fingerprint is lost.
"""
from __future__ import annotations

import os
import re
from pathlib import Path

from . import receiver

#: termlink's identity selectors, in precedence order. Any one already set wins
#: over the project file — an operator or a parent process chose it explicitly.
IDENTITY_ENV = ("TERMLINK_IDENTITY_FILE", "TERMLINK_AGENT_ID", "TERMLINK_IDENTITY_DIR")

#: Set by apply() when it moved this process off the host default; dm.py reads
#: it to know there is an old host-key rail set worth draining.
APPLIED_MARKER = "FW_SIDECAR_RAIL_IDENTITY_APPLIED"


def _framework_yaml_value(key: str) -> str | None:
    """Same parse as watcher._framework_yaml_value (kept local: watcher imports
    this module)."""
    try:
        text = (receiver._root() / ".framework.yaml").read_text(encoding="utf-8")
    except OSError:
        return None
    m = re.search(rf"^{re.escape(key)}:\s*['\"]?([^'\"#\n]+?)['\"]?\s*(#.*)?$", text, re.M)
    return m.group(1).strip() if m else None


def _config(key: str, default: str = "", environ=None) -> str:
    """fw_config's resolution order: FW_<KEY> env > .framework.yaml > default."""
    environ = os.environ if environ is None else environ
    val = environ.get(f"FW_{key}")
    if val is None:
        val = _framework_yaml_value(key)
    return default if val is None else val


def _truthy(val: str) -> bool:
    return val.strip().lower() in ("1", "true", "yes", "on")


def enabled(environ=None) -> bool:
    return _truthy(_config("SIDECAR_RAIL_IDENTITY", "0", environ))


def host_dm_transition(environ=None) -> bool:
    return _truthy(_config("SIDECAR_HOST_DM_TRANSITION", "1", environ))


def configured_path(environ=None) -> str:
    """RAIL_IDENTITY_FILE as lib/rail-identity.sh resolves it: relative paths
    against PROJECT_ROOT so .framework.yaml stays portable. '' when unset."""
    p = _config("RAIL_IDENTITY_FILE", "", environ).strip()
    if p and not os.path.isabs(p):
        p = str(Path(receiver._root()) / p)
    return p


def termlink_env(base=None) -> dict:
    """A copy of `base` (default os.environ) with the project signing identity
    selected — or unchanged when the switch is off, no RAIL_IDENTITY_FILE is
    configured, or any termlink identity selector is already set.

    Like `fw rail post`, a configured path that does not exist yet is used as
    is: termlink creates the keypair there on first use. Only a CONFIGURED path
    is ever used — never a guessed one (lib/rail-identity.sh, "TWO THINGS THAT
    WILL BITE")."""
    env = dict(os.environ if base is None else base)
    if any(env.get(k) for k in IDENTITY_ENV):
        return env
    if not enabled(env):
        return env
    path = configured_path(env)
    if not path:
        return env
    env["TERMLINK_IDENTITY_FILE"] = path
    env[APPLIED_MARKER] = path
    return env


def apply(environ=None) -> str | None:
    """Install termlink_env() into `environ` (default os.environ) once, at a
    sidecar entry point. Returns the identity file selected, or None when
    nothing changed. Never raises: a sidecar must not die over identity."""
    environ = os.environ if environ is None else environ
    try:
        env = termlink_env(environ)
    except Exception:
        return None
    path = env.get(APPLIED_MARKER)
    if not path or environ.get("TERMLINK_IDENTITY_FILE") == path:
        return None
    environ["TERMLINK_IDENTITY_FILE"] = path
    environ[APPLIED_MARKER] = path
    return path
