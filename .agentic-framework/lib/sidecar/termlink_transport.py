"""arc-011 sidecar — real TermLink transport and hub capability probe.

T-3405 (T-3397 Amendment 5, slice 3). Slices 1 and 2 built the outbox and the
delivery leg against injected fakes; this supplies the real implementations of
both seams.

**Transport.** Maps onto TermLink's own primitives rather than reinventing
them: `termlink channel post <topic> [--hub <addr>] --client-msg-id <id>`.
`--hub` present-or-absent IS the uniform path (Amendment 5), and
`--client-msg-id` is natively the dedupe primitive Amendment 5 said to reuse,
so a caller-owned retry is idempotent on TermLink's side rather than on ours.

**Probe — why it refuses more than it accepts.** TermLink's CLI grades hub
trust in rungs that do not imply each other, which is the whole point of
T-2415 (their measurement of a fleet that was "reachable + authenticating +
version-floor-exempt + structurally incapable, all at once"):

    termlink hub probe <addr>   TLS handshake, no auth   -> reachable
    termlink remote ping <hub>  needs a 32-byte secret   -> authenticating
    (no unauthenticated call)                            -> version: UNKNOWN

Amendment 5 makes the per-hub capability + version-floor check an acceptance
gate rather than a follow-up, so a hub whose version cannot be established is
**refused** — and the refusal says *version floor unestablished*, never
"unreachable", because collapsing those two is how a reachable-but-incapable
hub gets treated as a valid send target. The local hub (`hub: None`, the
degenerate case) can clear every rung, so it is the one that passes today.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess

from .delivery import ProbeResult, TransportError

#: Minimum TermLink version this sidecar will send through. The cross-hub
#: post semantics slice 2 relies on (a post either succeeds or fails loudly,
#: bypassing the offline queue) were confirmed against the 0.11 line during
#: T-3397; older hubs are refused rather than assumed compatible.
VERSION_FLOOR = (0, 11, 0)

_VERSION_RE = re.compile(r"termlink\s+(\d+)\.(\d+)\.(\d+)")


def _binary() -> str:
    return shutil.which("termlink") or "termlink"


def topic_for(msg: dict) -> str:
    """Topic a message is posted to. Addressed by recipient, not by hub.

    Offsets are hub-scoped and meaningless across hubs (G-060, no
    federation), so the topic carries the addressing and the
    `conversation_id` carries the thread — never a bare offset.
    """
    return f"sidecar:{msg['to']}"


def build_post_command(msg: dict, *, binary: str | None = None,
                       topic: str | None = None) -> list[str]:
    """Build the `channel post` argv. One shape; `--hub` is data, not a branch."""
    argv = [
        binary or _binary(), "channel", "post", topic or topic_for(msg),
        "--json",
        "--ensure-topic",
        "--msg-type", "sidecar.consult",
        "--client-msg-id", msg["client_msg_id"],
        # The hub keeps --client-msg-id as an out-of-band dedupe key and does
        # NOT echo it into the envelope (measured, T-3405). Carrying it in
        # metadata too makes the envelope self-describing, so a reader can
        # find a message by id — and so receiver-side dedupe is *possible*
        # once the hub's own 5-minute dedupe TTL has lapsed.
        "--metadata", f"client_msg_id={msg['client_msg_id']}",
        # T-3426 / TermLink @1640 meet-point 2: cv_key lands in the hub's
        # in-memory index, so `channel cv-keys <topic>` answers "does this
        # topic hold my id" without walking the topic. Process-local on the
        # hub (cleared on restart) — a reader must fall back to the walk when
        # the key is absent; absent is not an error.
        "--metadata", f"cv_key={msg['client_msg_id']}",
        "--metadata", f"conversation_id={msg['conversation_id']}",
        "--metadata", f"from_agent={msg['from']}",
        "--payload", msg["body"],
    ]
    hub = msg.get("hub")
    if hub:
        argv += ["--hub", hub]
    return argv


def termlink_transport(msg: dict, *, runner=subprocess.run,
                       binary: str | None = None,
                       topic: str | None = None, timeout: int = 15):
    """Post one message through TermLink. Raises TransportError on failure.

    Returns the posted offset when TermLink reports one. The offset is
    returned for evidence only — it is hub-scoped, so it is never used as
    an address (G-060).
    """
    argv = build_post_command(msg, binary=binary, topic=topic)
    try:
        proc = runner(argv, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        raise TransportError(f"channel post timed out after {timeout}s") from exc
    except FileNotFoundError as exc:
        raise TransportError("termlink binary not found on PATH") from exc

    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip().splitlines()
        raise TransportError(
            f"channel post exit {proc.returncode}: "
            f"{detail[-1][:200] if detail else 'no output'}")

    # Shape observed live (T-3405): {"confirmed": false, "delivered":
    # {"offset": N, "ts": ...}}. `confirmed` is TermLink's own
    # delivered-unconfirmed signal — the offset is a claim the post makes,
    # and reading the topic back is what turns it into evidence.
    try:
        return json.loads(proc.stdout).get("delivered", {}).get("offset")
    except (json.JSONDecodeError, AttributeError):
        return None


def parse_version(text: str) -> tuple[int, int, int] | None:
    match = _VERSION_RE.search(text or "")
    return tuple(int(g) for g in match.groups()) if match else None


def probe_hub(hub: str | None, *, runner=subprocess.run,
              binary: str | None = None,
              floor: tuple[int, int, int] = VERSION_FLOOR) -> ProbeResult:
    """Grade a hub as a send target. Refuses what it cannot establish."""
    binary = binary or _binary()

    if hub is None:
        try:
            proc = runner([binary, "version"], capture_output=True,
                          text=True, timeout=10)
        except (OSError, subprocess.SubprocessError) as exc:
            return ProbeResult(False, f"local termlink unavailable: {exc}")
        version = parse_version(proc.stdout) if proc.returncode == 0 else None
        if version is None:
            return ProbeResult(False, "local termlink version unreadable")
        if version < floor:
            return ProbeResult(
                False,
                f"local termlink {'.'.join(map(str, version))} is below the "
                f"version floor {'.'.join(map(str, floor))}")
        return ProbeResult(
            True, f"local hub, termlink {'.'.join(map(str, version))} meets floor")

    try:
        proc = runner([binary, "hub", "probe", hub, "--json"],
                      capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError) as exc:
        return ProbeResult(False, f"hub {hub} unreachable: {exc}")
    if proc.returncode != 0:
        return ProbeResult(False, f"hub {hub} unreachable: TLS handshake failed")

    # Reachable. That is a strictly weaker claim than capable, and saying so
    # is the gate: there is no unauthenticated version read, so the floor is
    # unestablished and the hub is not yet a valid send target (T-2415).
    return ProbeResult(
        False,
        f"hub {hub} is reachable but its version floor is unestablished — "
        "no unauthenticated version read exists (T-2415); supply hub "
        "credentials to clear this gate")
