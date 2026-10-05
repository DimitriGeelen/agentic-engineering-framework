"""arc-011 sidecar — where a recipient lives: its hub, and the topic on it.

T-3855 (ring20-dashboard T-2459 §5 item 3, operator-relayed 2026-10-05).

**The bug this exists to end.** `circuit.resolve_address` turns a bare `--to`
that is not a fleet project id into `<OUR hub>/<OUR project>/<name>` — an agent
under the sender. That is right for a sub-agent and wrong for everyone else.
Measured 2026-10-05: `fw sidecar send --to ring20-dashboard --hub
ring20-dashboard` posted to `inbox:cacc73ea32b121dd/999-Agentic-Engineering-
Framework/ring20-dashboard` — a topic in OUR namespace, created on THEIR hub by
`--ensure-topic` — and reported HUB_ACCEPTED/delivered. The recipient reads
`inbox:1389a831016c4bf1/ring20-dashboard`. 87 messages sat unread that way.
"Delivered" meant "the hub accepted a post to a topic nobody reads".

**The rule.** A recipient topic is built in the sender's namespace ONLY with
evidence that the recipient is the sender's sub-agent. Otherwise the topic is
anchored on the RECIPIENT's hub id, learned one of three ways:

  1. an explicit circuit, `--to <hubid>/<name>[/…]` — used verbatim;
  2. the peer directory (`.context/sidecar/peers.json`), learned from the
     `from_circuit` of envelopes we received — a peer that wrote to us told us
     its exact address;
  3. `--hub <profile|address>`: the hub's id read from that hub. The id is the
     first 16 hex of its TLS certificate fingerprint (`termlink hub
     fingerprint` locally); for a remote hub it is the fingerprint `termlink
     hub probe` sees, checked against termlink's TOFU pin for that address,
     and only for a hub we hold a hubs.toml credential for — the same
     credential `probe_hub` then uses for the authenticated version read before
     anything is posted.

When none of these resolves, the send is REFUSED by name — nothing is written
to the outbox and nothing is posted. Never a guessed topic, never "delivered".
"""

from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from . import circuit, outbox

PEERS_FILE = "peers.json"


class AddressError(circuit.CircuitError):
    """The recipient's hub or topic could not be established. Refuse."""


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _binary() -> str:
    return circuit._binary()


# ── peer directory ──────────────────────────────────────────────────────────

def peers_path() -> Path:
    return outbox._root() / ".context" / "sidecar" / PEERS_FILE


def load_peers() -> dict:
    try:
        data = json.loads(peers_path().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        data = {}
    if not isinstance(data, dict):
        data = {}
    data.setdefault("peers", {})
    data.setdefault("hubs", {})
    return data


def _save_peers(data: dict) -> None:
    path = peers_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(f".json.{os.getpid()}.tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")
    os.replace(tmp, path)


def strip_host(cid: str) -> str:
    """A circuit as a topic address: no `inbox:` prefix, no `//host/` head."""
    cid = (cid or "").strip()
    for prefix in (circuit.TOPIC_PREFIX, circuit.LEGACY_TOPIC_PREFIX):
        if cid.startswith(prefix):
            cid = cid[len(prefix):]
    if cid.startswith("//"):
        cid = cid[2:].split("/", 1)[1] if "/" in cid[2:] else ""
    return cid


def circuit_name(cid: str) -> str | None:
    """The name a circuit is addressed as: its agent, else its project."""
    parts = circuit.parse_circuit(cid)
    return parts.get("agent") or parts.get("project")


def learn(from_agent: str | None, from_circuit: str | None) -> bool:
    """Record a peer's exact address from an envelope we received.

    Keyed by the sender's `from_agent` (what our agent will type as `--to`)
    and by the circuit's own name. Returns True when something changed.
    """
    cid = strip_host(from_circuit or "")
    parts = circuit.parse_circuit(cid)
    if not cid or not parts.get("hub") or not parts.get("project"):
        return False
    names = {n for n in (from_agent, circuit_name(cid)) if n and "/" not in str(n)}
    if not names:
        return False
    data = load_peers()
    changed = False
    for name in names:
        prev = data["peers"].get(name) or {}
        if prev.get("circuit") != cid:
            data["peers"][name] = {"circuit": cid, "hub_id": parts["hub"], "learned_at": _now()}
            changed = True
    if changed:
        try:
            _save_peers(data)
        except OSError:
            return False
    return changed


def peer(name: str) -> dict | None:
    return load_peers()["peers"].get(name)


# ── hub ids ─────────────────────────────────────────────────────────────────

def own_hub_id() -> str:
    return circuit.hub_id()


def _fingerprint_hex(text: str | None) -> str | None:
    t = (text or "").strip()
    if t.startswith("sha256:"):
        t = t[len("sha256:"):]
    t = t.lower()
    if len(t) >= circuit.HUB_ID_LEN and all(c in "0123456789abcdef" for c in t):
        return t
    return None


def _tofu_pin(address: str, runner) -> str | None:
    try:
        proc = runner([_binary(), "tofu", "list", "--json"],
                      capture_output=True, text=True, timeout=10)
        entries = json.loads(proc.stdout or "{}").get("entries") or []
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError, AttributeError):
        return None
    for e in entries:
        if isinstance(e, dict) and e.get("host") == address:
            return _fingerprint_hex(e.get("fingerprint"))
    return None


def remote_hub_id(hub: str, *, runner=subprocess.run, hubs_file: Path | None = None,
                  use_cache: bool = True) -> tuple[str, str]:
    """(hub_id, address) for a `--hub` value (a hubs.toml profile name or an
    address). Raises AddressError naming exactly what is missing."""
    from . import termlink_transport as tt
    profiles, err = tt.hub_profiles(hub, hubs_file)
    path = Path(hubs_file) if hubs_file else tt.hubs_toml_path()
    gap = tt._credential_gap(hub, profiles, err, path)
    if gap:
        raise AddressError(
            f"cannot address a recipient on hub {hub}: no usable credential "
            f"({gap.split(': ', 1)[-1]})")
    address = str(next((p.get("address") for p in profiles if p.get("name") == hub and p.get("address")),
                       None) or next((p.get("address") for p in profiles if p.get("address")), hub))

    data = load_peers()
    cached = data["hubs"].get(hub)
    if use_cache and cached and cached.get("address") == address and cached.get("hub_id"):
        return cached["hub_id"], address

    try:
        proc = runner([_binary(), "hub", "probe", address, "--json"],
                      capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError) as exc:
        raise AddressError(f"hub {hub} ({address}) unreachable, its hub id unread: {exc}") from exc
    try:
        live = _fingerprint_hex(json.loads(proc.stdout or "{}").get("fingerprint"))
    except (json.JSONDecodeError, AttributeError):
        live = None
    if proc.returncode != 0 or not live:
        raise AddressError(f"hub {hub} ({address}): hub id unread — `termlink hub probe "
                           f"{address} --json` reported no certificate fingerprint")
    pinned = _tofu_pin(address, runner)
    if pinned and pinned != live:
        raise AddressError(
            f"hub {hub} ({address}) presents certificate {live[:16]} but termlink's TOFU pin "
            f"is {pinned[:16]} — refusing to address it (`termlink tofu verify {address}`)")
    hid = live[:circuit.HUB_ID_LEN]
    data["hubs"][hub] = {"hub_id": hid, "address": address,
                         "tofu_pinned": bool(pinned), "read_at": _now()}
    try:
        _save_peers(data)
    except OSError:
        pass
    return hid, address


def profile_for_hub_id(hid: str, *, runner=subprocess.run,
                       hubs_file: Path | None = None) -> str | None:
    """The hubs.toml profile that reaches hub `hid`. None = no profile does.

    Cached ids first; then each credentialed profile is read once. A profile
    pointing at our own hub is never returned for our own id (local = no --hub).
    """
    import tomllib
    from . import termlink_transport as tt
    for name, row in load_peers()["hubs"].items():
        if row.get("hub_id") == hid:
            return name
    path = Path(hubs_file) if hubs_file else tt.hubs_toml_path()
    try:
        names = list((tomllib.loads(path.read_text(encoding="utf-8")).get("hubs") or {}).keys())
    except (OSError, tomllib.TOMLDecodeError):
        return None
    for name in names:
        try:
            got, _ = remote_hub_id(name, runner=runner, hubs_file=hubs_file, use_cache=False)
        except AddressError:
            continue
        if got == hid:
            return name
    return None


def hub_arg_for(hid: str, *, runner=subprocess.run, hubs_file: Path | None = None) -> str | None:
    """`--hub` for a topic on hub `hid`: None for our own hub, else the profile.
    Raises AddressError when no profile reaches it."""
    if hid == own_hub_id():
        return None
    prof = profile_for_hub_id(hid, runner=runner, hubs_file=hubs_file)
    if not prof:
        raise AddressError(
            f"no termlink hub profile reaches hub {hid} — add one with "
            f"`termlink remote profile add <name> <host:port> --secret-file <path>` "
            f"(the hub's id is the first 16 hex of its certificate fingerprint)")
    return prof


# ── resolving a send ────────────────────────────────────────────────────────

def _subagent_evidence(name: str, runner) -> str | None:
    """Why `name` is a sub-agent of this agent, or None.

    A sub-agent's own sidecar creates `inbox:<our hub>/<our project>/<name>`
    on our hub (T-3803 `ensure_inbox_topic`); a registered receiver under that
    name is evidence too (lifecycle registry)."""
    from . import inbox, lifecycle
    topic = circuit.topic_for_circuit("/".join([own_hub_id(), circuit.project_id(), name]))
    try:
        present, _ = inbox.topic_present(topic, runner=runner)
    except Exception:
        present = False
    if present:
        return f"its inbox {topic} exists on this hub"
    try:
        if lifecycle.lookup(name) is not None:
            return "a receiver is registered under that name"
    except Exception:
        pass
    return None


def resolve(to: str, *, hub: str | None = None, level: str = "auto",
            runner=subprocess.run, hubs_file: Path | None = None) -> dict:
    """Where a `--to` goes: {circuit, topic, hub (None = local), how}.

    Raises AddressError (refuse, post nothing) when the recipient's hub cannot
    be established, or when a bare name has no evidence of being our sub-agent.
    """
    raw = strip_host((to or "").strip())
    if not raw:
        raise AddressError("empty recipient")
    own = own_hub_id()
    hub_id = None
    if hub:
        hub_id, _ = remote_hub_id(hub, runner=runner, hubs_file=hubs_file)
    remote = bool(hub_id and hub_id != own)

    def out(cid: str, hub_arg: str | None, how: str) -> dict:
        return {"circuit": cid, "topic": circuit.topic_for_circuit(cid),
                "hub": hub_arg, "how": how}

    # 1. an explicit circuit
    if "/" in raw:
        named = circuit.parse_circuit(raw).get("hub")
        if not named:
            raise AddressError(f"--to {raw} carries no hub segment")
        if hub:
            if named != hub_id:
                raise AddressError(
                    f"--to {raw} names hub {named}, but --hub {hub} is hub {hub_id} — "
                    "the topic would be created where its owner never reads")
            return out(raw, hub if remote else None, f"explicit circuit on hub {hub_id}")
        return out(raw, hub_arg_for(named, runner=runner, hubs_file=hubs_file),
                   f"explicit circuit on hub {named}")

    name = raw
    known = peer(name)

    # 2. a remote hub was named: the recipient lives there, never under us
    if remote:
        if known and known.get("hub_id") == hub_id:
            return out(known["circuit"], hub, f"peer directory (hub {hub_id})")
        if level == "agent":
            raise AddressError(
                f"{name} as an AGENT on hub {hub} needs its project: --to "
                f"{hub_id}/<project>/{name}")
        return out(f"{hub_id}/{name}", hub, f"project address on hub {hub} ({hub_id})")

    # 3. our own hub (no --hub, or --hub resolving to ourselves)
    hub_arg = hub if hub else None
    if known:
        if known.get("hub_id") == own:
            return out(known["circuit"], hub_arg, "peer directory (this hub)")
        if not hub:
            return out(known["circuit"],
                       hub_arg_for(known["hub_id"], runner=runner, hubs_file=hubs_file),
                       f"peer directory (hub {known['hub_id']})")
    if level == "project" or (level == "auto" and circuit.is_project_id(name)):
        return out(f"{own}/{name}", hub_arg, "project address on this hub")
    if level == "agent":
        return out(f"{own}/{circuit.project_id()}/{name}", hub_arg,
                   "sub-agent of this agent (--level agent)")
    why = _subagent_evidence(name, runner)
    if why:
        return out(f"{own}/{circuit.project_id()}/{name}", hub_arg, f"sub-agent: {why}")
    raise AddressError(
        f"recipient {name!r} is not resolvable: not a project id on this hub, not in "
        f"the peer directory ({peers_path()}), and not a sub-agent of this agent "
        f"(no inbox:{own}/{circuit.project_id()}/{name} on this hub). Address it as "
        f"--to <hubid>/{name}, or --hub <profile> for a peer on another hub, or "
        f"--level agent if it IS your sub-agent")
