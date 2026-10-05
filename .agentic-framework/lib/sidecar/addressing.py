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
import re
import subprocess
import sys
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

    T-3880: both envelope fields are sender-asserted, so neither may pick WHOSE
    address is being written. The address is learned only under the circuit's
    own name, only when `from_agent` (if given) agrees with it, and an existing
    entry is NEVER replaced by a different circuit — that is recorded as a
    conflict for the operator and refused. (Previously the entry was keyed by
    `from_agent` and last writer won: one posted envelope claiming to be
    ring20-manager redirected every later `--to ring20-manager`.)
    A first sighting is still trust-on-first-use; the authenticated hub id
    (TermLink T-3345, our T-3873) is what closes that.

    Returns True when something changed.
    """
    cid = strip_host(from_circuit or "")
    parts = circuit.parse_circuit(cid)
    if not cid or not parts.get("hub") or not parts.get("project"):
        return False
    name = circuit_name(cid)
    if not name or "/" in str(name):
        return False
    if from_agent and from_agent != name:
        return False   # the sender claims to be someone its own circuit is not
    data = load_peers()
    prev = data["peers"].get(name) or {}
    if prev.get("circuit") == cid:
        return False
    if prev.get("circuit"):
        conflicts = list(data.get("conflicts") or [])
        conflicts.append({"name": name, "known": prev["circuit"], "claimed": cid,
                          "at": _now(), "action": "refused"})
        data["conflicts"] = conflicts[-200:]
        try:
            _save_peers(data)
        except OSError:
            pass
        return False
    data["peers"][name] = {"circuit": cid, "hub_id": parts["hub"], "learned_at": _now()}
    try:
        _save_peers(data)
    except OSError:
        return False
    return True


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


def _authenticated_hub_id(hub: str, runner) -> tuple[str | None, str | None]:
    """(hub_id, hub_instance_id) from `termlink remote ping <hub> --json`, or
    (None, None) when the call fails or the hub does not report an id."""
    try:
        proc = runner([_binary(), "remote", "ping", hub, "--json"],
                      capture_output=True, text=True, timeout=15)
        doc = json.loads(proc.stdout or "{}") if proc.returncode == 0 else {}
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return None, None
    hid = doc.get("hub_id") if isinstance(doc, dict) else None
    if not isinstance(hid, str) or not re.fullmatch(r"[0-9a-f]{%d}" % circuit.HUB_ID_LEN, hid):
        return None, None
    inst = doc.get("hub_instance_id")
    return hid, inst if isinstance(inst, str) else None


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

    # T-3873: the hub states its own id over an AUTHENTICATED call (TermLink
    # T-3345: `remote ping --json` → hub_id, hub_instance_id). Read it; never
    # derive it — hub_id stops being the fingerprint prefix once canonical-id
    # minting lands. The fingerprint stays only as the warned fallback for hubs
    # that return no hub_id.
    auth_id, auth_inst = _authenticated_hub_id(hub, runner)

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
    if auth_id:
        # The instance the authenticated call reached must be the certificate
        # we were shown; a disagreement is never resolved by picking one.
        inst = _fingerprint_hex(auth_inst) if auth_inst else None
        if inst and inst != live:
            raise AddressError(
                f"hub {hub} ({address}): authenticated hub_instance_id {inst[:16]} does not "
                f"match the certificate it presents ({live[:16]}) — refusing to address it")
        hid, source = auth_id, "authenticated"
    else:
        hid, source = live[:circuit.HUB_ID_LEN], "fingerprint"
        print(f"fw sidecar: WARNING: hub {hub} returned no authenticated hub_id (TermLink "
              f"older than T-3345?); using its certificate fingerprint prefix {hid}",
              file=sys.stderr)
    data["hubs"][hub] = {"hub_id": hid, "address": address, "source": source,
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


def _project_inboxes_on(hub: str, hub_id: str, runner) -> list[str] | None:
    """Project names with an inbox on a remote hub (`inbox:<hub_id>/<project>`,
    no deeper segment), or None when the hub could not be asked (T-3899)."""
    from . import inbox
    prefix = f"inbox:{hub_id}/"
    argv = [inbox._binary(), "channel", "list", "--prefix", prefix, "--json", "--hub", hub]
    try:
        proc = runner(argv, capture_output=True, text=True, timeout=15)
        if proc.returncode != 0:
            return None
        names = [t.get("name") or "" for t in json.loads(proc.stdout or "{}").get("topics", [])]
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError, AttributeError):
        return None
    return sorted({n[len(prefix):] for n in names
                   if n.startswith(prefix) and n[len(prefix):] and "/" not in n[len(prefix):]})


def _require_remote_inbox(name: str, hub: str, hub_id: str, runner) -> None:
    """T-3899: a bare name sent to a remote hub is a PROJECT there only if its
    inbox exists. Without this check the send's `--ensure-topic` created
    `inbox:<hub_id>/<name>` for a project that does not exist and reported it
    delivered (ring20-dashboard 2026-10-05: `--to ring20-manager` — a hub
    profile name — landed in a topic nobody reads; the project is
    proxmox-ring20-management). Refuse instead, naming what does exist."""
    from . import inbox
    topic = circuit.topic_for_circuit(f"{hub_id}/{name}")
    present, why = inbox.topic_present(topic, runner=runner, hub=hub)
    if present is True:
        return
    if present is None:
        raise AddressError(
            f"cannot verify that {topic} exists on hub {hub} ({why}); nothing posted. "
            f"Address it by explicit circuit, --to {hub_id}/<project>, once you know its inbox")
    known = _project_inboxes_on(hub, hub_id, runner)
    listed = ", ".join(known) if known else "none could be listed"
    raise AddressError(
        f"no inbox {topic} on hub {hub} ({hub_id}): {name!r} is not a project there "
        f"(a hub profile name is not a project name). Project inboxes on that hub: "
        f"{listed}. Use --to {hub_id}/<project>; nothing posted")


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
        _require_remote_inbox(name, hub, hub_id, runner)
        return out(f"{hub_id}/{name}", hub, f"project address on hub {hub} ({hub_id}), inbox present")

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
