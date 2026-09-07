"""T-3310 (arc-020 S4): claim-based election for exactly-one provisioning.

Implements D5 bound 1 / Q-A / F5 of the identity design ratified in
docs/reports/T-3287-identity-taxonomy-circuit-model.md, on top of the S2
claim mechanism (lib/aef_circuit.WriteClaim — imported, not duplicated)
and the S3 provision walk (lib/aef_resolve.provision). Serves G4.

The model carried here:

  - A broadcast for a missing target can reach N candidates; without an
    election every candidate provisions and the fleet gets N instances of
    one peer. The election is the idempotency bound (D5 bound 1): the
    target is a mutex, candidates race to CLAIM it, exactly one wins and
    proceeds to provision, the rest back off cleanly (Q-A,
    first-to-claim-locks — F5's v1 policy; bidding/supervisor-assign are
    v2 options and deliberately absent).
  - Losing is a RESULT, not an error, and carries no retry: a loser gets
    a LOST result naming the holder and stops. No retry storm — the
    winner's provision makes the target exist, so there is nothing left
    for a loser to do (ensure-exists semantics).
  - The claim backend is INJECTABLE. The default (LocalClaimBackend) is
    the S2-style advisory claim file — O_CREAT|O_EXCL with {holder, pid,
    ts}, stale-pid breaking — one file per election target, plus an
    optional TTL so a hung (live-pid) winner cannot hold a target
    forever. The termlink-channel-claim adapter (F5's eventual substrate:
    `termlink channel claim` / `release` / `claims`) is defined here as a
    SHAPE ONLY (TermlinkChannelClaimBackend) — real wiring is later work.
  - Release/expiry returns the target to the electable state: the winner
    releases on completion (or on a raise — the release is in a finally);
    a crashed winner's claim is broken by the next candidate via the S2
    stale-pid check; a hung winner's claim expires via TTL.

Pure stdlib.
"""

from __future__ import annotations

import calendar
import hashlib
import json
import os
import shutil
import subprocess
import threading
import time
from dataclasses import dataclass, replace as _dc_replace
from pathlib import Path
from typing import Callable, Mapping, Protocol, runtime_checkable

try:  # imported as lib.aef_election (test convention) or standalone
    from .aef_address import AEFAddress, parse, serialize
    from .aef_circuit import WriteClaim
    from .aef_resolve import ProvisionResult, provision
except ImportError:  # pragma: no cover — lib/ directly on sys.path
    from aef_address import AEFAddress, parse, serialize
    from aef_circuit import WriteClaim
    from aef_resolve import ProvisionResult, provision

WON = "won"
LOST = "lost"

# Election claims live beside the S2 registry, one file per target.
ELECTION_DIR = Path(".context") / "circuits" / "elections"

_TS_FMT = "%Y-%m-%dT%H:%M:%SZ"


class ElectionError(Exception):
    """Base error for election operations."""


# ── the injectable backend shape ─────────────────────────────────────────


@runtime_checkable
class ClaimTicket(Protocol):
    """The winner's handle on a held claim. release() is idempotent."""

    def release(self) -> None: ...


@runtime_checkable
class ClaimBackend(Protocol):
    """One election substrate: a mutex per target address.

    try_claim() is a SINGLE non-blocking attempt (the no-retry-storm
    property lives here): a ticket when the caller now holds the target,
    None when someone else does. holder() reads who holds it (a free
    read — never mutates).
    """

    def try_claim(
        self, target_wire: str, candidate_id: str
    ) -> ClaimTicket | None: ...

    def holder(self, target_wire: str) -> dict | None: ...


# ── default backend: the S2 claim file, per target (+ TTL) ───────────────


def election_claim_path(root: str | Path, target_wire: str) -> Path:
    """Where the local backend keeps the claim file for one target."""
    digest = hashlib.sha256(target_wire.encode()).hexdigest()[:16]
    return Path(root) / ELECTION_DIR / f"{digest}.claim"


class _ElectionClaim(WriteClaim):
    """S2 WriteClaim mechanics on a per-target path, plus TTL expiry.

    The acquire loop, {holder, pid, ts} payload shape, stale-pid
    breaking, and idempotent release are inherited from
    lib.aef_circuit.WriteClaim unchanged. This subclass redirects the
    claim-file path (one per election target, not one per project), adds
    the TTL leg of staleness — a claim older than ttl seconds is
    breakable even while its pid is alive (a hung winner must not hold a
    target forever) — and makes the take ATOMIC WITH ITS PAYLOAD: the
    payload is written to a temp file first and hard-linked into place
    (link fails like O_EXCL when the claim exists), so a contender can
    never observe a claim file whose payload is not yet written. The S2
    open-then-write take has that window, and losers reading holder()
    mid-race hit it.
    """

    def __init__(
        self,
        root: str | Path,
        target_wire: str,
        holder: str,
        ttl: float | None = None,
    ):
        super().__init__(root, holder=holder)
        self.path = election_claim_path(root, target_wire)
        self.ttl = ttl

    def _try_take(self) -> bool:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_name(
            f".{os.getpid()}.{threading.get_ident()}.tmp"
        )
        tmp.write_text(
            json.dumps(
                {
                    "holder": self.holder,
                    "pid": os.getpid(),
                    "ts": time.strftime(_TS_FMT, time.gmtime()),
                }
            )
        )
        try:
            os.link(tmp, self.path)  # atomic take, payload included
        except FileExistsError:
            return False
        finally:
            tmp.unlink(missing_ok=True)
        self._held = True
        return True

    def _break_if_stale(self) -> None:
        super()._break_if_stale()  # S2 leg: dead pid
        if self.ttl is None:
            return
        claim = self.current()
        if claim is None:
            return
        try:
            born = calendar.timegm(time.strptime(claim.get("ts"), _TS_FMT))
        except (TypeError, ValueError):
            return  # unreadable ts is not proof of expiry
        if time.time() - born >= self.ttl:
            try:
                self.path.unlink()
            except FileNotFoundError:
                pass


class LocalClaimTicket:
    """Ticket over a held _ElectionClaim."""

    def __init__(self, claim: _ElectionClaim):
        self._claim = claim
        self.released = False

    def release(self) -> None:
        self._claim.release()
        self.released = True


class LocalClaimBackend:
    """Default backend: advisory claim file per target (the S2 mechanism).

    ``ttl`` (seconds) bounds how long any claim on any target may be
    held before it becomes breakable; None (default) means claims only
    break on a dead holder pid.
    """

    def __init__(self, root: str | Path, ttl: float | None = None):
        self.root = Path(root)
        self.ttl = ttl

    def try_claim(
        self, target_wire: str, candidate_id: str
    ) -> LocalClaimTicket | None:
        claim = _ElectionClaim(
            self.root, target_wire, holder=candidate_id, ttl=self.ttl
        )
        # timeout=0.0 → one take attempt, one stale-break, one re-take,
        # then give up. No polling loop: losers back off, never storm.
        if claim.acquire(timeout=0.0):
            return LocalClaimTicket(claim)
        return None

    def holder(self, target_wire: str) -> dict | None:
        return _ElectionClaim(
            self.root, target_wire, holder="__probe__", ttl=self.ttl
        ).current()


# ── termlink adapter: LIVE wiring (T-3335 / arc-020 S8) ──────────────────

DEFAULT_ELECTION_TTL_MS = 60_000
DEFAULT_ELECTION_SENTINEL = "aef-election-token"


def default_termlink_invoke(args: list[str], *, timeout: float = 20.0) -> dict:
    """Run ``termlink <args>`` and normalise the result.

    Returns ``{ok, code, data, stdout, stderr}`` where ``data`` is the parsed
    JSON body when stdout is JSON, else ``{}``. Never raises on a non-zero
    exit (a lost claim is a normal outcome, not an error) — only on a missing
    binary, which is a genuine environment fault the caller must see.
    """
    binary = shutil.which("termlink") or "termlink"
    try:
        proc = subprocess.run(
            [binary, *args], capture_output=True, text=True, timeout=timeout
        )
    except FileNotFoundError as exc:  # pragma: no cover — env fault
        raise ElectionError(f"termlink binary not found: {exc}") from exc
    out = (proc.stdout or "").strip()
    data: object = {}
    if out:
        try:
            data = json.loads(out)
        except json.JSONDecodeError:
            data = {}
    return {
        "ok": proc.returncode == 0,
        "code": proc.returncode,
        "data": data,
        "stdout": out,
        "stderr": (proc.stderr or "").strip(),
    }


def election_topic(channel: str, target_wire: str) -> str:
    """Per-target claim topic: a stable, collision-resistant name under the
    election ``channel`` namespace. Same address → same topic, always."""
    digest = hashlib.sha256(target_wire.encode()).hexdigest()[:16]
    return f"{channel}-{digest}"


class TermlinkClaimTicket:
    """Winner's handle over a held ``channel claim`` lease. Idempotent, and
    tolerant of a lapsed lease (a TTL-expired claim is already 'released')."""

    def __init__(
        self,
        invoke: Callable[..., dict],
        topic: str,
        offset: int,
        claim_id: str,
        claimer: str,
    ):
        self._invoke = invoke
        self.topic = topic
        self.offset = offset
        self.claim_id = claim_id
        self.claimer = claimer
        self.released = False

    def release(self) -> None:
        if self.released:
            return
        # Mutex reopen: NO --ack (we are not consuming posted work, we are
        # returning the election slot to the electable state). Best-effort:
        # a hub CLAIM_EXPIRED means the lease already lapsed → already reopen.
        self._invoke(
            [
                "channel",
                "release",
                "--claim-id",
                self.claim_id,
                "--claimer",
                self.claimer,
                "--json",
            ]
        )
        self.released = True


class TermlinkChannelClaimBackend:
    """Live ``ClaimBackend`` over the ``termlink channel claim`` family (F5).

    The election target (a serialized V9 address) is the mutex key. termlink's
    claim primitive is an *offset lease within a topic* (T-2032 work-queue
    semantics), not a free-form named mutex — so a target maps onto a
    ``(topic, offset)`` coordinate:

      - topic  = ``election_topic(channel, target_wire)`` — one topic per target
      - offset = 0 — the single mutex slot, seeded with one sentinel message
                 (an offset cannot be claimed at/beyond the frontier, so the
                 slot must exist before it can be raced for — hub code -32022)

    Mapping onto the protocol:

      try_claim → seed(topic) then ``channel claim --claimer <id> <topic> 0``
      release   → ``channel release --claim-id <id> --claimer <id>``  (no --ack)
      holder    → ``channel claims <topic>``  (read the live lease on offset 0)

    The claim is a renew-or-lapse *lease* (``ttl_ms``, default 60s, hub-clamped
    to 1h): a crashed winner's slot reopens on TTL expiry (matching the S2
    stale-pid semantics), but a winner whose provision outlives ``ttl_ms`` must
    renew — see the task ## Decisions (T-3335). Inject ``invoke`` in tests to
    exercise every path with no live hub.
    """

    def __init__(
        self,
        channel: str,
        invoke: Callable[..., dict] | None = None,
        *,
        ttl_ms: int = DEFAULT_ELECTION_TTL_MS,
        sentinel: str = DEFAULT_ELECTION_SENTINEL,
    ):
        self.channel = channel
        self._invoke = invoke or default_termlink_invoke
        self.ttl_ms = ttl_ms
        self.sentinel = sentinel

    # -- helpers ----------------------------------------------------------

    def _topic(self, target_wire: str) -> str:
        return election_topic(self.channel, target_wire)

    def _ensure_seeded(self, topic: str) -> None:
        """Idempotently ensure the topic exists and offset 0 is postable.

        A concurrent first-post can seat two sentinels (offsets 0 and 1); that
        is harmless — every candidate still races offset 0, so exactly one wins.
        """
        self._invoke(["channel", "create", topic])  # idempotent; ignore result
        info = self._invoke(["channel", "info", topic, "--json"])
        count = 0
        data = info.get("data")
        if info.get("ok") and isinstance(data, dict):
            count = data.get("count") or 0
        if not count:
            self._invoke(["channel", "post", topic, self.sentinel, "--json"])

    # -- ClaimBackend protocol -------------------------------------------

    def try_claim(
        self, target_wire: str, candidate_id: str
    ) -> "TermlinkClaimTicket | None":
        topic = self._topic(target_wire)
        self._ensure_seeded(topic)
        res = self._invoke(
            [
                "channel",
                "claim",
                "--claimer",
                candidate_id,
                "--ttl-ms",
                str(self.ttl_ms),
                "--json",
                topic,
                "0",
            ]
        )
        data = res.get("data")
        if (
            res.get("ok")
            and isinstance(data, dict)
            and data.get("ok")
            and data.get("claim_id")
        ):
            return TermlinkClaimTicket(
                self._invoke, topic, 0, data["claim_id"], candidate_id
            )
        # Not won. LOST if someone else already holds the slot; a genuine
        # error (hub down, topic fault) if nobody holds it and we still failed.
        held = self.holder(target_wire)
        if held is not None:
            if held.get("holder") == candidate_id:
                # We already hold it (idempotent re-claim / renew race).
                return TermlinkClaimTicket(
                    self._invoke, topic, 0, held.get("claim_id"), candidate_id
                )
            return None  # a rival holds it → role=LOST
        raise ElectionError(
            f"channel-claim failed on {topic!r}: "
            f"{res.get('stderr') or res.get('stdout') or 'exit ' + str(res.get('code'))}"
        )

    def holder(self, target_wire: str) -> dict | None:
        topic = self._topic(target_wire)
        res = self._invoke(["channel", "claims", "--json", topic])
        data = res.get("data")
        if not isinstance(data, dict):
            return None
        for row in data.get("claims") or []:
            try:
                if int(row.get("offset", -1)) == 0:
                    return {
                        "holder": row.get("claimer"),
                        "claim_id": row.get("claim_id"),
                        "claimed_until": row.get("claimed_until"),
                        "topic": topic,
                        "offset": 0,
                    }
            except (TypeError, ValueError):
                continue
        return None


# ── the election ─────────────────────────────────────────────────────────


@dataclass(frozen=True)
class ElectionResult:
    """Outcome of one candidate's single claim attempt on a target."""

    role: str  # WON / LOST
    target: str  # serialized target address (the election key)
    candidate_id: str
    holder: dict | None  # who holds the claim (self when WON)
    ticket: ClaimTicket | None = None  # winner-only: the release handle
    provision: ProvisionResult | None = None  # set by elect_and_provision

    @property
    def won(self) -> bool:
        return self.role == WON

    def release(self) -> None:
        """Winner returns the target to the electable state."""
        if self.ticket is None:
            raise ElectionError(
                f"{self.candidate_id!r} lost this election — only the "
                "winner holds a claim to release"
            )
        self.ticket.release()


def elect(
    target: AEFAddress | str,
    candidate_id: str,
    claim_backend: ClaimBackend,
) -> ElectionResult:
    """One candidate's single attempt to win the target (D5 bound 1).

    Exactly one concurrent caller per target gets role=WON (the backend's
    mutex decides — first-claim-wins, F5); everyone else gets role=LOST
    with the holder named, and MUST back off: a LOST result is terminal
    for this broadcast, not a cue to retry. The winner proceeds to
    provision and releases via the returned ticket (or lets crash/TTL
    breaking return the target to the electable state).
    """
    if not candidate_id:
        raise ElectionError("candidate_id must be non-empty")
    addr = parse(target) if isinstance(target, str) else target
    target_wire = serialize(addr)
    ticket = claim_backend.try_claim(target_wire, candidate_id)
    if ticket is None:
        return ElectionResult(
            role=LOST,
            target=target_wire,
            candidate_id=candidate_id,
            holder=claim_backend.holder(target_wire),
        )
    return ElectionResult(
        role=WON,
        target=target_wire,
        candidate_id=candidate_id,
        holder=claim_backend.holder(target_wire),
        ticket=ticket,
    )


def elect_and_provision(
    target: AEFAddress | str,
    candidate_id: str,
    claim_backend: ClaimBackend,
    probe: Callable[[AEFAddress], bool],
    provisioners: Mapping[str, Callable[[AEFAddress], AEFAddress | None]],
    *,
    release_on_completion: bool = True,
    **provision_kwargs,
) -> ElectionResult:
    """Run the election, and route ONLY the winner into the S3 provision walk.

    The winner holds the claim across the whole resolve+provision descent,
    so concurrent electors for the same target serialize: while one
    provisions, the rest LOSE and back off; by the time the claim returns
    to the electable state the target exists, so any later winner's walk
    resolves ALREADY_EXISTS and materializes nothing (ensure-exists — the
    broadcast storm provisions ONE, not N).

    A loser's result carries ``provision=None`` — the walk was never
    entered. ``release_on_completion=True`` (default) releases in a
    finally, so completion AND an in-process crash both return the target
    to the electable state; pass False to keep holding (release via the
    result's ticket). All ``provision_kwargs`` pass through to
    lib.aef_resolve.provision (admission, audit_sink, path_exists, ...).
    """
    result = elect(target, candidate_id, claim_backend)
    if not result.won:
        return result
    try:
        outcome = provision(result.target, probe, provisioners, **provision_kwargs)
        return _dc_replace(result, provision=outcome)
    finally:
        if release_on_completion:
            result.ticket.release()
