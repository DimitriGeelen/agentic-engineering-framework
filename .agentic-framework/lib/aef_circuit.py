"""T-3308 (arc-020 S2): circuit registry + three-state lifecycle.

Implements the circuit half of the identity design ratified in
docs/reports/T-3287-identity-taxonomy-circuit-model.md (D1, D4-A/B/C, D7),
on top of the S1 address library (lib/aef_address.py — do not duplicate).

The model carried here:

  - A circuit is a channel to a SPECIFIC agent-instance (D1): its id is the
    V9 circuit address — durable name + the ``session=`` token. The id is
    transient; only the caller's retained reference persists.
  - Three states (D4): ``live`` (profile current), ``dormant`` (session
    alive, profile not current but re-instatable), ``dead`` (proven gone).
    ``dead`` is terminal — recovery is a NEW circuit under the durable name
    (S3's ladder), never a resurrection of this id.
  - Dormant -> live is the FAST PATH (D4-B): a retained circuit id
    reactivates the profile in the already-known session with NO
    rediscovery. It is bounded by the session's profile registry: the
    session must be known and must carry the profile, else reactivation is
    UNAVAILABLE (which is not death — see below).
  - Death requires POSITIVE PROOF (D4-A): a resolve-walk DOWN the retained
    address (host -> hub -> project -> "is session=S alive?") that completes
    and fails to find the session. A timeout, an unreachable observation, or
    a walk that errors out is INCONCLUSIVE and never changes state. S3 owns
    the real ladder; here the walk is an injectable callable.
  - Reconnection re-plugs into the project context fabric (D4-C): the
    fabric state is loaded AT reconnect time from the project (level 3, the
    passive durable home), so the resumed state is the agent's own latest
    project-durable state — possibly grown since the switch — never a
    frozen snapshot cached at establishment.
  - Writes serialize through a per-project write-claim (D7): every registry
    mutation acquires the project's advisory claim; reads fan out freely.

Persistence: append-only JSONL (``.context/circuits/registry.jsonl``),
last-write-wins per circuit id on replay. Pure stdlib.
"""

from __future__ import annotations

import json
import os
import time
from dataclasses import asdict, dataclass, replace
from pathlib import Path
from typing import Callable, Iterable, Mapping

try:  # imported as lib.aef_circuit (test convention) or standalone
    from .aef_address import AEFAddress, parse, serialize
except ImportError:  # pragma: no cover — lib/ directly on sys.path
    from aef_address import AEFAddress, parse, serialize

LIVE = "live"
DORMANT = "dormant"
DEAD = "dead"
STATES = (LIVE, DORMANT, DEAD)

# The only sanctioned route into DEAD (D4-A). Internal defense: _transition
# refuses `dead` unless the caller names this route.
_VIA_RESOLVE_WALK = "resolve-walk"

_LEGAL = {
    (LIVE, DORMANT),
    (DORMANT, LIVE),
    (LIVE, DEAD),
    (DORMANT, DEAD),
}

REGISTRY_DIR = Path(".context") / "circuits"
REGISTRY_FILE = "registry.jsonl"
CLAIM_FILE = ".write-claim"


class CircuitError(Exception):
    """Base error for circuit registry operations."""


class IllegalTransition(CircuitError):
    """A transition outside the D4 lifecycle (e.g. anything out of dead)."""


class ReactivationUnavailable(CircuitError):
    """D4-B fast path not applicable: session unknown or lacks the profile.

    This is NOT death — the circuit stays in its current state. Death needs
    the resolve-walk proof (D4-A); the caller escalates to the ladder (S3).
    """


class WriteClaimHeld(CircuitError):
    """The per-project write-claim (D7) is held by another writer."""


# ── per-project write-claim (D7, advisory v1) ────────────────────────────


class WriteClaim:
    """Advisory single-writer claim for the project's shared fabric (D7).

    v1 mechanism: an O_CREAT|O_EXCL claim file carrying {holder, pid, ts}.
    A claim whose recorded pid is no longer alive is stale and may be
    broken. Reads never touch the claim.
    """

    def __init__(self, project_root: str | Path, holder: str | None = None):
        self.path = Path(project_root) / REGISTRY_DIR / CLAIM_FILE
        self.holder = holder or f"pid:{os.getpid()}"
        self._held = False

    def acquire(self, timeout: float = 0.0, poll: float = 0.05) -> bool:
        """Try to take the claim; returns False if contested past timeout."""
        deadline = time.monotonic() + timeout
        while True:
            if self._try_take():
                return True
            self._break_if_stale()
            if self._try_take():
                return True
            if time.monotonic() >= deadline:
                return False
            time.sleep(poll)

    def release(self) -> None:
        if self._held:
            try:
                self.path.unlink()
            except FileNotFoundError:
                pass
            self._held = False

    def __enter__(self) -> "WriteClaim":
        if not self.acquire():
            raise WriteClaimHeld(f"write-claim held: {self.current()}")
        return self

    def __exit__(self, *exc) -> None:
        self.release()

    def current(self) -> dict | None:
        """Read the claim file (a free read — no claim needed)."""
        try:
            return json.loads(self.path.read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            return None

    def _try_take(self) -> bool:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        try:
            fd = os.open(self.path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            return False
        with os.fdopen(fd, "w") as fh:
            json.dump(
                {"holder": self.holder, "pid": os.getpid(), "ts": _now()}, fh
            )
        self._held = True
        return True

    def _break_if_stale(self) -> None:
        claim = self.current()
        if claim is None:
            return
        pid = claim.get("pid")
        if pid is None or _pid_alive(int(pid)):
            return
        try:
            self.path.unlink()
        except FileNotFoundError:
            pass


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


# ── records ──────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class CircuitRecord:
    """One established circuit, keyed by its transient circuit id (D1)."""

    circuit_id: str  # serialized V9 circuit address (durable + session=)
    durable_id: str  # serialized durable name (the correspondent)
    state: str
    established: str
    updated: str
    unreachable_count: int = 0  # timeout/unreachable observations — NEVER state
    last_via: str = "establish"

    @property
    def address(self) -> AEFAddress:
        return parse(self.circuit_id)


@dataclass(frozen=True)
class ReconnectResult:
    """Outcome of a reactivate/reconnect (D4-B + D4-C)."""

    record: CircuitRecord
    fabric_state: object  # the agent's own latest project-durable state
    fast_path: bool  # True = no rediscovery was performed


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def default_fabric_loader(project_path: str) -> dict:
    """Default D4-C re-plug: point at the project's context fabric as it is NOW.

    Deliberately thin for v1 — the property that matters is that this runs
    at reconnect time against the project (level 3), so the state is the
    latest project-durable state, not a snapshot from establishment.
    """
    context_dir = Path(project_path) / ".context"
    return {
        "project": project_path,
        "context_dir": str(context_dir),
        "context_exists": context_dir.is_dir(),
        "attached_ts": _now(),
    }


# ── registry ─────────────────────────────────────────────────────────────


class CircuitRegistry:
    """Registry of established circuits with the D4 three-state lifecycle.

    Persistence is an append-only JSONL under the project
    (``.context/circuits/registry.jsonl``); the current state is the
    last-write-wins replay per circuit id. Mutations serialize through the
    per-project write-claim (D7); reads replay the file freely.
    """

    def __init__(
        self,
        project_root: str | Path,
        holder: str | None = None,
        claim_timeout: float = 2.0,
    ):
        self.root = Path(project_root)
        self.path = self.root / REGISTRY_DIR / REGISTRY_FILE
        self.claim_timeout = claim_timeout
        self._holder = holder

    # ── reads (fan out freely — no claim) ────────────────────────────────

    def get(self, circuit_id: str) -> CircuitRecord | None:
        return self._load().get(circuit_id)

    def list(self, state: str | None = None) -> list[CircuitRecord]:
        records = self._load().values()
        if state is None:
            return sorted(records, key=lambda r: r.circuit_id)
        if state not in STATES:
            raise CircuitError(f"unknown state {state!r} (allowed: {STATES})")
        return sorted(
            (r for r in records if r.state == state), key=lambda r: r.circuit_id
        )

    # ── lifecycle mutations (serialize through the write-claim) ──────────

    def establish(self, address: AEFAddress | str) -> CircuitRecord:
        """Record a newly established circuit (state: live).

        The address must be a full circuit id (D1): a durable name — host,
        project, @agent (hub optional per D6) — bound to a session= token.
        """
        addr = parse(address) if isinstance(address, str) else address
        if not addr.is_circuit:
            raise CircuitError(
                "a circuit id carries the session= token (D3); "
                f"got the durable form {serialize(addr)!r}"
            )
        for level in ("host", "project", "agent"):
            if getattr(addr, level) is None:
                raise CircuitError(
                    f"circuit address needs {level} — a circuit reaches a "
                    "specific agent-instance in a specific project (D1/D2)"
                )
        circuit_id = serialize(addr)
        if self.get(circuit_id) is not None:
            raise CircuitError(
                f"circuit {circuit_id!r} already established; a recovered "
                "endpoint gets a NEW circuit id (D1), never a reused one"
            )
        ts = _now()
        record = CircuitRecord(
            circuit_id=circuit_id,
            durable_id=serialize(addr.to_durable()),
            state=LIVE,
            established=ts,
            updated=ts,
        )
        self._write(record)
        return record

    def mark_dormant(self, circuit_id: str) -> CircuitRecord:
        """Profile switched away: the circuit goes dormant, not dead (D4)."""
        record = self._require(circuit_id)
        if record.state == DORMANT:
            return record
        return self._transition(record, DORMANT, via="profile-switch")

    def record_unreachable(
        self, circuit_id: str, reason: str = "timeout"
    ) -> CircuitRecord:
        """Log a timeout/unreachable observation. NEVER changes state (D4-A).

        Invalidation requires positive proof of death via death_test(); an
        unanswered attempt is inconclusive by ruling, however many pile up.
        """
        record = self._require(circuit_id)
        updated = replace(
            record,
            unreachable_count=record.unreachable_count + 1,
            updated=_now(),
            last_via=f"unreachable:{reason}",
        )
        self._write(updated)
        return updated

    def reactivate(
        self,
        circuit_id: str,
        session_profiles: Mapping[str, Iterable[str]]
        | Callable[[str], Iterable[str] | None],
        fabric: Callable[[str], object] | None = None,
    ) -> ReconnectResult:
        """D4-B fast path: reactivate a dormant profile with NO rediscovery.

        ``session_profiles`` is the session's profile registry — a mapping
        (or callable) from session id to the profiles that session can
        wear. The fast path applies iff the session is known AND carries
        the profile; otherwise ReactivationUnavailable (state unchanged —
        unavailability is not death). No resolver is consulted: the whole
        point of the retained circuit id is skipping discovery.

        On success the circuit re-plugs into the project fabric (D4-C):
        ``fabric`` is called with the project path at reconnect time, so
        the resumed state is the agent's own latest project-durable state.
        Reconnecting a live circuit is legal and just re-plugs.
        """
        record = self._require(circuit_id)
        if record.state == DEAD:
            raise IllegalTransition(
                f"circuit {circuit_id!r} is dead — dead is terminal (D1); "
                "climb the ladder and establish a NEW circuit"
            )
        addr = record.address
        profiles = self._profiles_for(session_profiles, addr.session)
        if profiles is None:
            raise ReactivationUnavailable(
                f"session {addr.session!r} not in the profile registry; "
                "not proof of death — run death_test() / the ladder (S3)"
            )
        if addr.agent not in set(profiles):
            raise ReactivationUnavailable(
                f"session {addr.session!r} does not carry profile "
                f"@{addr.agent} (D4-B bound); state unchanged"
            )
        if record.state == DORMANT:
            record = self._transition(record, LIVE, via="reactivate")
        loader = fabric or default_fabric_loader
        return ReconnectResult(
            record=record,
            fabric_state=loader(addr.project),
            fast_path=True,
        )

    def death_test(
        self, circuit_id: str, resolve_walk: Callable[[AEFAddress], bool]
    ) -> CircuitRecord:
        """D4-A: the ONLY route into dead.

        ``resolve_walk`` walks DOWN the retained address (host -> hub ->
        project -> session) and returns True iff it found the session
        (carrying the profile). Only a walk that COMPLETES and returns
        False proves death. A walk that raises (timed out, host
        unreachable) is inconclusive: the exception propagates and the
        state is untouched. S3 supplies the real ladder walk.
        """
        record = self._require(circuit_id)
        if record.state == DEAD:
            return record  # already proven; idempotent
        found = resolve_walk(record.address)
        if found:
            updated = replace(
                record, updated=_now(), last_via="resolve-walk:found"
            )
            self._write(updated)
            return updated
        return self._transition(record, DEAD, via=_VIA_RESOLVE_WALK)

    # ── internals ────────────────────────────────────────────────────────

    @staticmethod
    def _profiles_for(session_profiles, session_id):
        if callable(session_profiles):
            return session_profiles(session_id)
        return session_profiles.get(session_id)

    def _require(self, circuit_id: str) -> CircuitRecord:
        record = self.get(circuit_id)
        if record is None:
            raise CircuitError(f"unknown circuit {circuit_id!r}")
        return record

    def _transition(
        self, record: CircuitRecord, new_state: str, via: str
    ) -> CircuitRecord:
        if new_state == DEAD and via != _VIA_RESOLVE_WALK:
            raise IllegalTransition(
                "dead requires positive proof via the resolve-walk (D4-A); "
                f"route {via!r} may not kill a circuit"
            )
        if (record.state, new_state) not in _LEGAL:
            raise IllegalTransition(
                f"{record.state} -> {new_state} is not a D4 transition"
            )
        updated = replace(
            record, state=new_state, updated=_now(), last_via=via
        )
        self._write(updated)
        return updated

    def _claim(self) -> WriteClaim:
        return WriteClaim(self.root, holder=self._holder)

    def _write(self, record: CircuitRecord) -> None:
        claim = self._claim()
        if not claim.acquire(timeout=self.claim_timeout):
            raise WriteClaimHeld(
                f"project write-claim held by {claim.current()!r}; "
                "writes serialize (D7) — retry or wait"
            )
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            with open(self.path, "a") as fh:
                fh.write(json.dumps(asdict(record)) + "\n")
                fh.flush()
                os.fsync(fh.fileno())
        finally:
            claim.release()

    def _load(self) -> dict[str, CircuitRecord]:
        records: dict[str, CircuitRecord] = {}
        try:
            lines = self.path.read_text().splitlines()
        except FileNotFoundError:
            return records
        for line in lines:
            line = line.strip()
            if not line:
                continue
            data = json.loads(line)
            records[data["circuit_id"]] = CircuitRecord(**data)
        return records
