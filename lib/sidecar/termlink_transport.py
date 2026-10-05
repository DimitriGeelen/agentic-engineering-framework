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
degenerate case) can clear every rung.

T-3806: a remote hub clears the version rung through an AUTHENTICATED read,
using the credential termlink already holds for it — its `~/.termlink/hubs.toml`
profile (secret_file + TOFU pin) — via `termlink fleet doctor --json`, which
calls `hub.version` per profile. No profile, or an unreadable secret_file, is
refused by name. docs/reports/T-3806-cross-hub-send.md.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

from . import circuit
from .delivery import ProbeResult, TransportError, is_auth_failure

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

    T-3433: the topic is now `inbox:<circuit-id>`, because TermLink treats
    only `inbox:*`/`dm:*` as mail. `to` decides which form
    (lib/sidecar/circuit.py owns the derivation, and is the only place that
    does): a bare project id resolves to the durable role address, a bare
    agent name to an agent under our project, and a `to` that already
    contains `/` is used verbatim. `msg["address_level"]` overrides the
    heuristic when a caller knows better than `is_project_id` can.
    """
    return circuit.topic_for_name(msg["to"], level=msg.get("address_level") or "auto")


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
        # T-3433: the sender's FULL (host-qualified) circuit id, so origin is
        # precise even when the destination is coarse — a consult answered at
        # a project-level address can still be traced to the exact agent that
        # asked. `from_agent` stays for compatibility with readers written
        # before the circuit existed.
        "--metadata", f"from_circuit={msg.get('from_circuit') or circuit.circuit_id('full')}",
        "--payload", msg["body"],
    ]
    if msg.get("in_reply_to"):
        # T-3804: NOT metadata.in_reply_to — termlink reads that key as a
        # parent OFFSET for its thread views. A message id gets its own key.
        argv[argv.index("--payload"):argv.index("--payload")] = [
            "--metadata", f"in_reply_to_msg_id={msg['in_reply_to']}"]
    if msg.get("urgent"):
        # T-3684: urgency survives the hub fallback (R5) — the receiving
        # watcher injects it at once instead of waiting for readiness.
        argv[argv.index("--payload"):argv.index("--payload")] = ["--metadata", "urgent=1"]
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
              floor: tuple[int, int, int] = VERSION_FLOOR,
              hubs_file: Path | None = None) -> ProbeResult:
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

    # `hub probe` wants an address; a hubs.toml profile name resolves to its own.
    named, _ = hub_profiles(hub, hubs_file)
    address = next((p["address"] for p in named if p["name"] == hub and p.get("address")), hub)
    try:
        proc = runner([binary, "hub", "probe", address, "--json"],
                      capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError) as exc:
        return ProbeResult(False, f"hub {hub} unreachable: {exc}")
    if proc.returncode != 0:
        return ProbeResult(False, f"hub {hub} unreachable: TLS handshake failed")

    # Reachable. That is a strictly weaker claim than capable (T-2415): the
    # version needs an AUTHENTICATED read. T-3806: use the credential termlink
    # already holds for this hub (its hubs.toml profile) rather than refusing
    # every remote hub with advice no code path could follow.
    return _authenticated_floor(hub, runner=runner, binary=binary,
                                floor=floor, hubs_file=hubs_file)


def hubs_toml_path() -> Path:
    """termlink's saved hub profiles (`termlink remote profile`)."""
    return Path.home() / ".termlink" / "hubs.toml"


def hub_profiles(hub: str, hubs_file: Path | None = None) -> tuple[list[dict], str | None]:
    """Profiles in hubs.toml naming `hub` by profile name or address.

    Returns (profiles, error). `error` is set when the file is absent or
    unparseable — itself a missing-credential answer, named by path.
    """
    import tomllib
    path = Path(hubs_file) if hubs_file else hubs_toml_path()
    if not path.exists():
        return [], f"no termlink hub profiles file at {path}"
    try:
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as exc:
        return [], f"{path} is unreadable: {exc}"
    out = []
    for name, prof in (data.get("hubs") or {}).items():
        if isinstance(prof, dict) and hub in (name, prof.get("address")):
            out.append(dict(prof, name=name))
    return out, None


def _credential_gap(hub: str, profiles: list[dict], err: str | None, path: Path) -> str | None:
    """Exactly which credential is missing, and where it is configured — or None."""
    head = f"hub {hub} is reachable but its version floor is unestablished: "
    remedy = f"add one with `termlink remote profile add <name> {hub} --secret-file <path>`"
    if err:
        return f"{head}{err}; {remedy}"
    if not profiles:
        return f"{head}no profile in {path} has name or address {hub}; {remedy}"
    gaps = []
    for prof in profiles:
        if prof.get("secret"):
            return None
        sf = prof.get("secret_file")
        if not sf:
            gaps.append(f"profile {prof['name']} in {path} sets neither secret_file nor secret")
        elif not os.access(sf, os.R_OK):
            gaps.append(f"profile {prof['name']} in {path} names secret_file {sf}, "
                        "which is missing or unreadable")
        else:
            return None
    return head + "; ".join(gaps)


def _authenticated_floor(hub: str, *, runner, binary: str, floor, hubs_file) -> ProbeResult:
    path = Path(hubs_file) if hubs_file else hubs_toml_path()
    profiles, err = hub_profiles(hub, path)
    gap = _credential_gap(hub, profiles, err, path)
    if gap:
        # T-3905 (G-109): no usable credential is about the SENDER — final.
        return ProbeResult(False, gap, credential_refused=True)

    # The one authenticated, per-profile version read the termlink CLI offers:
    # `fleet doctor` calls `hub.version` on every hubs.toml profile with that
    # profile's secret and TOFU pin. It walks the whole fleet (no single-hub
    # filter) — docs/reports/T-3806-cross-hub-send.md has the cost and the
    # TermLink-side ask.
    try:
        proc = runner([binary, "fleet", "doctor", "--json", "--timeout", "5"],
                      capture_output=True, text=True, timeout=90)
    except (OSError, subprocess.SubprocessError) as exc:
        return ProbeResult(False, f"hub {hub}: authenticated version read failed: {exc}")
    try:
        rows = json.loads(proc.stdout or "{}").get("hubs") or []
    except (json.JSONDecodeError, AttributeError):
        return ProbeResult(False, f"hub {hub}: authenticated version read returned "
                                  "unparseable output (termlink fleet doctor --json)")
    names = [p["name"] for p in profiles]
    mine = [r for r in rows if r.get("hub") in names]
    if not mine:
        return ProbeResult(False, f"hub {hub}: termlink fleet doctor did not report "
                                  f"profile {', '.join(names)}")
    failures = []
    auth_failures = 0
    for row in mine:
        version = parse_version(f"termlink {row.get('hub_version') or ''}")
        if row.get("status") != "ok" or version is None:
            detail = row.get('error') or row.get('diagnostic') or 'no hub_version reported'
            auth_failures += is_auth_failure(str(detail))
            failures.append(
                f"profile {row.get('hub')} (secret {row.get('secret_source') or 'unknown'}): "
                f"{detail}")
            continue
        vs, fs = ".".join(map(str, version)), ".".join(map(str, floor))
        if version < floor:
            return ProbeResult(False, f"hub {hub} runs termlink {vs}, below the version floor {fs}")
        return ProbeResult(True, f"hub {hub} (profile {row['hub']}), authenticated, "
                                 f"termlink {vs} meets floor")
    # T-3905 (G-109): every profile was REJECTED on its credential — final.
    return ProbeResult(False, f"hub {hub} is reachable but the authenticated version read "
                              "failed: " + "; ".join(failures),
                       credential_refused=bool(failures) and auth_failures == len(failures))
