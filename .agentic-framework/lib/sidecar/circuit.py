"""arc-011 sidecar — circuit ids: the one place an address is derived.

T-3433 (operator ruling 2026-09-22, D-599; resolves OBS-453). Consult topics
move from `sidecar:<agent-id>` to `inbox:<circuit-id>`, because TermLink
treats only `inbox:*` and `dm:*` as **mail** — wake events (`inbox.queued`,
hub `channel.rs:949`), receipts, `--await-ack` — and treats everything else
as a bare append log. We take their prefix and keep our identity: what
follows `inbox:` is the framework's circuit id.

**The ladder** (T-3287 D3's order, which this reuses rather than reinventing):

    host  /  hub  /  project  /  session  /  agent

**The four emitted forms**, and why exactly these:

    <hub>/<project>                        project level — the DURABLE ROLE
                                           ADDRESS. What peers reach us on;
                                           survives session restarts.
    <hub>/<project>/<agent>                agent under a project, session not
                                           claimed (the dispatched-worker case)
    <hub>/<project>/<session>/<agent>      exact circuit, session distinct
    //<host>/<hub>/<project>[/…]           host-qualified FULL id, metadata only

**Why the address starts at `hub`, not at `host`.** A topic is an object on a
hub, so the hub id is the anchor; the host is where an *agent* runs. Measured
2026-09-22: `010-termlink` is on another host and the *same* hub (it reads and
writes our topics directly — agent-chat-arc @1640/@1651), and we do not know
its FQDN. Putting our host into a peer's address would assert a fact we do not
have, which is precisely the "never invent a level" rule. The host is not
dropped — it rides in `metadata.from_circuit` as the host-qualified form, so
origin stays precise even when the destination is coarse.

**Why `//` marks the host.** The forms are positional, so the host has to be
distinguishable from a hub by something other than counting: a project-level
full id and an agent-under-project address are both three segments. A leading
`//` is the RFC 3986 authority marker and splits to an empty first segment,
which is unambiguous and costs three lines.

**Why session==agent collapses to the 3-form.** The dispatch stanza
(`agents/termlink/termlink.sh`) exports `FW_SIDECAR_AGENT_ID=<worker name>`
AND `FW_FOCUS_SESSION_KEY=<worker name>` — one string, two levels. Emitting
it twice would be honest but would also mean a peer addressing that worker by
name could not derive the same string. Collapsing makes sender-derived and
receiver-derived topics *identical*, which is the property the address exists
to have. The 3-form claims only "this agent, under this project"; it does not
claim a session.
"""

from __future__ import annotations

import os
import re
import shutil
import socket
import subprocess

from . import outbox

#: The identity ladder, outermost first. `parse_circuit` returns exactly these
#: keys; a level the address does not carry comes back None, never guessed.
LEVELS = ("host", "hub", "project", "session", "agent")

TOPIC_PREFIX = "inbox:"
#: Read-only transition alias for one release (T-3433). Senders never write it.
LEGACY_TOPIC_PREFIX = "sidecar:"

#: Fleet project-id convention: three digits, a dash, a name — `010-termlink`,
#: `999-Agentic-Engineering-Framework`, `003-NTB-ATC-Plugin`. Used to tell a
#: peer PROJECT id from an AGENT name when `--to` is bare; see `is_project_id`.
_PROJECT_ID_RE = re.compile(r"^\d{3}-")

_FINGERPRINT_RE = re.compile(r"sha256:([0-9a-f]{16})")

#: How many hex characters of the hub fingerprint name the hub. TermLink's
#: `hub fingerprint` prints a full sha256; 16 is what the fleet quotes.
HUB_ID_LEN = 16

_hub_cache: str | None = None


class CircuitError(RuntimeError):
    """An address could not be derived. Raised, never papered over with a
    placeholder — an address with an invented level routes to nowhere and
    looks like it routed somewhere."""


def _binary() -> str:
    return shutil.which("termlink") or "termlink"


# ── the five levels ─────────────────────────────────────────────────────────

def host_fqdn() -> str:
    """This host's name. `FW_SIDECAR_HOST` overrides for tests and for hosts
    whose `getfqdn()` answer differs from the name the fleet knows them by."""
    return os.environ.get("FW_SIDECAR_HOST") or socket.getfqdn()


def hub_id(*, runner=subprocess.run, refresh: bool = False) -> str:
    """First `HUB_ID_LEN` hex of `termlink hub fingerprint`.

    Cached in-process and on disk (`.context/sidecar/hub-id`) because every
    address derivation needs it and the fingerprint does not move while a hub
    lives. `FW_SIDECAR_HUB_ID` overrides both.
    """
    global _hub_cache
    env = os.environ.get("FW_SIDECAR_HUB_ID")
    if env:
        return env
    if _hub_cache and not refresh:
        return _hub_cache

    cache_path = outbox._root() / ".context" / "sidecar" / "hub-id"
    if not refresh and cache_path.exists():
        cached = cache_path.read_text(encoding="utf-8").strip()
        if cached:
            _hub_cache = cached
            return cached

    try:
        proc = runner([_binary(), "hub", "fingerprint"],
                      capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.SubprocessError) as exc:
        raise CircuitError(f"hub fingerprint unavailable: {exc}") from exc
    match = _FINGERPRINT_RE.search(proc.stdout or "")
    if proc.returncode != 0 or not match:
        raise CircuitError(
            "hub fingerprint unreadable — no address can be derived without a "
            "hub anchor (`termlink hub fingerprint`, or set FW_SIDECAR_HUB_ID)")
    _hub_cache = match.group(1)
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(_hub_cache + "\n", encoding="utf-8")
    return _hub_cache


def project_id() -> str:
    """This project's fleet id.

    The existing convention, not a second derivation (L-399): basename of the
    project root — `lib/pickup.sh:42` (`local_project=$(basename "$PROJECT_ROOT")`),
    the same string `lib/publish-learning-to-bus.sh:54` and
    `lib/subscribe-learnings-from-bus.sh:50` use, and the same one
    `inbox.agent_id()` already defaulted to via `outbox._root().name`.
    """
    return outbox._root().name


def session_id() -> str | None:
    """The live session. `TERMLINK_SESSION` when TermLink wraps us, else the
    framework's focus session key. A parent session has neither — and then the
    project-level address IS its inbox, which is correct, not degraded."""
    return (os.environ.get("TERMLINK_SESSION")
            or os.environ.get("FW_FOCUS_SESSION_KEY") or None)


def agent_name() -> str:
    """This agent's addressable name (`FW_SIDECAR_AGENT_ID`, else the project).

    NOT the TermLink identity fingerprint: that is machine-wide (T-3405), so
    it names a host, not an agent, and cannot route a consult.
    """
    return os.environ.get("FW_SIDECAR_AGENT_ID") or project_id()


# ── composing ───────────────────────────────────────────────────────────────

def _agent_path(hub: str, project: str, session: str | None, agent: str) -> list[str]:
    parts = [hub, project]
    if agent and agent != project:
        if session and session != agent:
            parts += [session, agent]
        else:
            parts += [agent]          # session==agent (dispatched worker) collapses
    elif session and session != project:
        parts += [session]
    return parts


def circuit_id(level: str = "agent", *, hub: str | None = None,
               project: str | None = None, session: str | None = None,
               agent: str | None = None, host: str | None = None) -> str:
    """This agent's circuit id at `level`.

    `project` — the durable role address, `<hub>/<project>`.
    `agent`   — the exact circuit, truncated to project level when this agent
                is the project (a parent session with no distinct agent).
    `full`    — host-qualified, `//<host>/…`; for `metadata.from_circuit` only.
    """
    hub = hub or hub_id()
    project = project or project_id()
    if level == "project":
        return "/".join([hub, project])
    if level not in ("agent", "full"):
        raise ValueError(f"unknown circuit level: {level!r}")
    session = session if session is not None else session_id()
    agent = agent or agent_name()
    parts = _agent_path(hub, project, session, agent)
    if level == "full":
        return "//" + "/".join([host or host_fqdn()] + parts)
    return "/".join(parts)


def parse_circuit(cid: str) -> dict:
    """Split a circuit id into the five levels. Missing levels are None.

    Positional, resolved by segment count; a leading `//` marks a
    host-qualified id (the only form that carries a host).
    """
    cid = (cid or "").strip()
    for prefix in (TOPIC_PREFIX, LEGACY_TOPIC_PREFIX):
        if cid.startswith(prefix):
            cid = cid[len(prefix):]
            break
    out = {level: None for level in LEVELS}
    if not cid:
        return out

    host_qualified = cid.startswith("//")
    parts = [p for p in cid[2:].split("/") if p] if host_qualified \
        else [p for p in cid.split("/") if p]
    if host_qualified:
        if not parts:
            return out
        out["host"] = parts.pop(0)

    keys = ("hub", "project", "session", "agent")
    if len(parts) >= 4:
        for key, value in zip(keys, parts[:4]):
            out[key] = value
    elif len(parts) == 3:
        # agent under a project, session not claimed (the collapsed 3-form)
        out["hub"], out["project"], out["agent"] = parts
    else:
        for key, value in zip(keys, parts):
            out[key] = value
    return out


def topic_for_circuit(cid: str) -> str:
    """`inbox:<cid>` — the address IS the topic. Host-qualified ids are not
    addresses (a topic lives on a hub), so their host is dropped here."""
    if cid.startswith("//"):
        cid = cid[2:].split("/", 1)[1] if "/" in cid[2:] else ""
    return f"{TOPIC_PREFIX}{cid}"


def legacy_topic_for(name: str) -> str:
    """The `sidecar:<name>` topic this address used to be. Read alias only."""
    return f"{LEGACY_TOPIC_PREFIX}{name}"


# ── resolving a `--to` ──────────────────────────────────────────────────────

def is_project_id(name: str) -> bool:
    """Is a bare `--to` a PROJECT (durable role address) or an AGENT?

    Three signals, any of which is enough: it is us; it is a sibling project
    directory on this host; or it matches the fleet's `NNN-Name` project
    numbering (`010-termlink`, `999-Agentic-Engineering-Framework`). Agent
    names in this corpus — `e2e-<run>-responder`, `t3433-circuit-addr`,
    `reviewer-T-3433-ab12` — match none of them.
    """
    if not name or "/" in name:
        return False
    if name == project_id():
        return True
    if _PROJECT_ID_RE.match(name):
        return True
    sibling = outbox._root().parent / name
    return sibling.is_dir() and (sibling / ".framework.yaml").exists()


def resolve_address(name: str, *, level: str = "auto") -> str:
    """Circuit id for a `--to`/`inbox_topic()` argument.

    A name containing `/` is already a circuit and is used verbatim. Otherwise
    `level` decides, and `auto` asks `is_project_id`.
    """
    name = (name or "").strip()
    for prefix in (TOPIC_PREFIX, LEGACY_TOPIC_PREFIX):
        if name.startswith(prefix):
            name = name[len(prefix):]
    if not name:
        raise CircuitError("empty address")
    if name.startswith("//"):
        name = name[2:].split("/", 1)[1] if "/" in name[2:] else name[2:]
    if "/" in name:
        return name
    if level == "auto":
        level = "project" if is_project_id(name) else "agent"
    if level == "project":
        return "/".join([hub_id(), name])
    if level == "agent":
        # An agent name addressed bare is an agent under OUR project; its
        # session is not ours to claim, so the 3-form is what we can honestly
        # say — and it is the same string the worker derives for itself.
        return "/".join([hub_id(), project_id(), name])
    raise ValueError(f"unknown address level: {level!r}")


def topic_for_name(name: str, *, level: str = "auto") -> str:
    return topic_for_circuit(resolve_address(name, level=level))
