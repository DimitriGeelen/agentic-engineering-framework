"""T-3309 (arc-020 S3): regressive resolution + provisioning ladder.

Implements the ladder ratified in
docs/reports/T-3287-identity-taxonomy-circuit-model.md (D1, D4, D5, D7),
on top of the S1 address library (lib/aef_address.py — climb()/ladder()
supply the token-drop) and the S2 circuit registry (lib/aef_circuit.py —
the WriteClaim mechanism is imported, not duplicated).

The model carried here:

  - RESOLVE (find what exists) is ungated and SIDE-EFFECT-FREE (D5): the
    walk climbs 5->1 by dropping the rightmost address token
    (AEFAddress.climb) and probes each rung through an injectable
    endpoint-probe callable. Nothing else is touched.
  - The return contract is TRI-STATE, per the S2 Evolution handoff (D4-A
    sharpened during T-3308): a walk that COMPLETES and fails to find the
    endpoint is DEFINITIVE (``not-found``); a walk that cannot complete
    (a probe raises) is INDETERMINATE — the distinction lives in the
    return type, not in prose. death_test_walk() adapts this back into
    the found/not-found/raise contract CircuitRegistry.death_test binds.
  - PROVISION shares the SAME walk skeleton: resolve first, and only when
    the walk definitively finds nothing does it materialize the missing
    suffix TOP-DOWN (nearest existing ancestor first), through injectable
    per-level provisioner callables. Tier-3 pre-authorization extends
    through hub-standup ONLY (D5): a plan that would require standing up
    a HOST is refused — the host is the one rung the ladder may ask, never
    create.
  - The project is passive and path-bound (D2/D5 bound 3): a missing
    project PATH halts provisioning with a hand-to-S6 signal (fleet
    repo-sourcing). The ladder never creates project paths.
  - Provisioning a session acquires the per-project write-claim (D7,
    lib/aef_circuit.WriteClaim) BEFORE any fabric mutation and releases
    it when the descent ends.
  - Seams for later slices, pinned by tests: every provision decision
    passes through an injectable admission-check callable (S5 governor;
    default v1 = allow) and emits an audit row through an injectable
    audit-sink callable (S7; default appends to the result's own list).
    D5 bound 4: every auto-provision is logged, unconditionally.

Pure stdlib.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Callable, Mapping

try:  # imported as lib.aef_resolve (test convention) or standalone
    from .aef_address import AEFAddress, parse, serialize
    from .aef_circuit import WriteClaim, WriteClaimHeld
except ImportError:  # pragma: no cover — lib/ directly on sys.path
    from aef_address import AEFAddress, parse, serialize
    from aef_circuit import WriteClaim, WriteClaimHeld

# ── resolve outcomes (tri-state, the S2 Evolution contract) ──────────────
FOUND = "found"
NOT_FOUND = "not-found"  # definitive: the walk COMPLETED, endpoint absent
INDETERMINATE = "indeterminate"  # could not walk — never proof of anything

# ── provision outcomes ───────────────────────────────────────────────────
PROVISIONED = "provisioned"
ALREADY_EXISTS = "already-exists"  # resolve found the endpoint; nothing to do
REFUSED = "refused"  # plan exceeds the hub-standup authorization ceiling (D5)
HALTED = "halted"  # project path missing on disk — hand to S6 (D5 bound 3)
DENIED = "denied"  # the admission check (S5 seam) blocked a provision step

HANDOFF_S6 = "S6"

# Containment order, level 1 -> 5. Descent materializes in this order.
_LEVELS = ("host", "hub", "project", "session", "agent")


class ResolveError(Exception):
    """Base error for ladder operations."""


class ResolveIndeterminate(ResolveError):
    """Raised by death_test_walk when the walk could not complete (D4-A)."""


class ProvisionError(ResolveError):
    """A provision walk could not run (bad target, missing provisioner)."""


# ── records ──────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class ProbeAttempt:
    """One rung probed during a resolve walk (the side-effect-free trail)."""

    address: str  # serialized rung
    outcome: str  # "exists" / "absent" / "error"
    error: str | None = None


@dataclass(frozen=True)
class ResolveResult:
    """Outcome of a resolve walk. Tri-state by construction (D4-A).

    ``found_at`` is the deepest EXISTING rung (== target when FOUND);
    ``missing`` lists the rungs probed absent, shallowest-first (the
    top-down materialization order a provision walk needs).
    """

    outcome: str  # FOUND / NOT_FOUND / INDETERMINATE
    target: str  # serialized target address
    found_at: str | None
    missing: tuple[str, ...]
    trail: tuple[ProbeAttempt, ...]
    error: str | None = None  # for INDETERMINATE: what stopped the walk

    @property
    def is_definitive(self) -> bool:
        return self.outcome != INDETERMINATE


@dataclass(frozen=True)
class ProvisionResult:
    """Outcome of a provision walk over the shared ladder skeleton."""

    outcome: str  # PROVISIONED / ALREADY_EXISTS / REFUSED / HALTED / DENIED / INDETERMINATE
    resolve: ResolveResult
    materialized: tuple[str, ...]  # serialized addresses, top-down
    audit: tuple[dict, ...]  # every provision decision, unconditionally
    handoff: str | None = None  # HANDOFF_S6 when halted on a missing path
    reason: str | None = None


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _as_address(target: AEFAddress | str) -> AEFAddress:
    return parse(target) if isinstance(target, str) else target


# ── the resolve walk (ungated, side-effect-free — D5) ────────────────────


def resolve(
    target: AEFAddress | str,
    probe: Callable[[AEFAddress], bool],
) -> ResolveResult:
    """Climb 5->1 from ``target`` to locate the deepest existing endpoint.

    ``probe(addr) -> bool`` answers "does this rung exist?" for one rung;
    True = exists, False = definitively absent. A probe that RAISES means
    the walk could not complete: the result is INDETERMINATE (state of the
    world unknown), never a not-found. The walk calls probe and nothing
    else — no writes, no gates (D5: resolve is ungated on every rung).
    """
    addr = _as_address(target)
    target_wire = serialize(addr)
    trail: list[ProbeAttempt] = []
    missing: list[AEFAddress] = []
    for rung in addr.ladder():
        rung_wire = serialize(rung)
        try:
            exists = probe(rung)
        except Exception as exc:  # could not walk — indeterminate by ruling
            trail.append(ProbeAttempt(rung_wire, "error", error=str(exc)))
            return ResolveResult(
                outcome=INDETERMINATE,
                target=target_wire,
                found_at=None,
                missing=(),
                trail=tuple(trail),
                error=f"probe failed at {rung_wire!r}: {exc}",
            )
        if exists:
            trail.append(ProbeAttempt(rung_wire, "exists"))
            return ResolveResult(
                outcome=FOUND if rung == addr else NOT_FOUND,
                target=target_wire,
                found_at=rung_wire,
                missing=tuple(serialize(r) for r in reversed(missing)),
                trail=tuple(trail),
            )
        trail.append(ProbeAttempt(rung_wire, "absent"))
        missing.append(rung)
    # Walk completed with every rung absent (even the host): definitive.
    return ResolveResult(
        outcome=NOT_FOUND,
        target=target_wire,
        found_at=None,
        missing=tuple(serialize(r) for r in reversed(missing)),
        trail=tuple(trail),
    )


def death_test_walk(
    probe: Callable[[AEFAddress], bool],
) -> Callable[[AEFAddress], bool]:
    """Adapt resolve() to CircuitRegistry.death_test's bound contract (D4-A).

    Returns a callable that walks the retained address and returns True
    iff the endpoint was found, False on a COMPLETED walk that found
    nothing (positive proof of death), and raises ResolveIndeterminate
    when the walk could not complete — so an unwalkable world can never
    kill a circuit.
    """

    def walk(address: AEFAddress) -> bool:
        result = resolve(address, probe)
        if not result.is_definitive:
            raise ResolveIndeterminate(result.error or "walk did not complete")
        return result.outcome == FOUND

    return walk


# ── the provision walk (same skeleton, Tier-3 bounded — D5) ──────────────


def _rung_fields(addr: AEFAddress | None) -> set[str]:
    if addr is None:
        return set()
    return {f for f in _LEVELS if getattr(addr, f) is not None}


def _provision_plan(found_at: AEFAddress | None, target: AEFAddress) -> list[str]:
    """Levels to materialize, top-down (containment order).

    A level is in the plan when the target names it (or, for session,
    when the target names an AGENT — level 4 is the minimum runnable
    unit, so an agent always needs a session to host it, even under a
    durable target that carries no session= token) and the deepest
    existing rung does not already have it.
    """
    have = _rung_fields(found_at)
    plan = []
    for level in _LEVELS:
        needed = getattr(target, level) is not None or (
            level == "session" and target.agent is not None
        )
        if needed and level not in have:
            plan.append(level)
    return plan


def _default_path_exists(path: str) -> bool:
    return Path(path).is_dir()


def _default_admission(level: str, intended: AEFAddress) -> bool:
    """S5 seam, v1 default: allow. The load-adaptive governor replaces this."""
    return True


def provision(
    target: AEFAddress | str,
    probe: Callable[[AEFAddress], bool],
    provisioners: Mapping[str, Callable[[AEFAddress], AEFAddress | None]],
    *,
    admission: Callable[[str, AEFAddress], bool] | None = None,
    audit_sink: Callable[[dict], None] | None = None,
    path_exists: Callable[[str], bool] | None = None,
    claim_timeout: float = 2.0,
    claim_holder: str | None = None,
) -> ProvisionResult:
    """Resolve, and materialize the missing suffix top-down when absent.

    Shares resolve()'s walk: the descent starts at the deepest EXISTING
    ancestor the resolve walk located and materializes each missing level
    downward through ``provisioners[level]``. A provisioner receives the
    intended child address (the working address plus the target's value
    for that level; ``session=None`` when the target is durable — the
    provisioner mints a fresh id, per D1 a recovered endpoint is a NEW
    instance, never a resurrection) and returns the materialized address,
    or None to accept the intended one as-is.

    Structural bounds (D5), in the order they fire:
      - an INDETERMINATE resolve provisions NOTHING — acting on an
        unwalkable world would smuggle timeout-death back in;
      - a plan needing a HOST is refused (Tier-3 pre-authorization runs
        through hub-standup only);
      - a missing project PATH halts with handoff=S6 (paths are never
        created here — D5 bound 3);
      - every step consults ``admission`` (S5 seam; default allow) and
        emits an audit row (S7 seam; D5 bound 4 — unconditional);
      - materializing a session acquires the project write-claim (D7)
        before the fabric mutation and releases it when the descent ends.
    """
    addr = _as_address(target)
    if addr.host is None:
        raise ProvisionError(
            "provision target needs host= — the ladder asks a host, it "
            "never invents one"
        )
    audit_rows: list[dict] = []

    def emit(level: str, address: str, decision: str, reason: str | None = None):
        row = {"ts": _now(), "level": level, "address": address, "decision": decision}
        if reason:
            row["reason"] = reason
        audit_rows.append(row)
        if audit_sink is not None:
            audit_sink(row)

    def result(outcome, res, materialized=(), handoff=None, reason=None):
        return ProvisionResult(
            outcome=outcome,
            resolve=res,
            materialized=tuple(materialized),
            audit=tuple(audit_rows),
            handoff=handoff,
            reason=reason,
        )

    res = resolve(addr, probe)
    if res.outcome == FOUND:
        return result(ALREADY_EXISTS, res)
    if res.outcome == INDETERMINATE:
        return result(
            INDETERMINATE, res,
            reason="resolve walk could not complete; provisioning on an "
            "unproven absence is forbidden (D4-A)",
        )

    working = parse(res.found_at) if res.found_at is not None else None
    plan = _provision_plan(working, addr)

    if "host" in plan:
        reason = (
            "no reachable host: standing up a host exceeds the Tier-3 "
            "pre-authorization ceiling (hub-standup only, D5)"
        )
        emit("host", serialize(addr), "refused", reason)
        return result(REFUSED, res, reason=reason)

    if "project" in plan:
        exists = (path_exists or _default_path_exists)(addr.project)
        if not exists:
            reason = (
                f"project path {addr.project!r} not on disk — the ladder "
                "never creates project paths; hand to S6 fleet-sourcing "
                "(D5 bound 3)"
            )
            emit("project", serialize(addr), "halted", reason)
            return result(HALTED, res, handoff=HANDOFF_S6, reason=reason)

    admit = admission or _default_admission
    materialized: list[str] = []
    claim: WriteClaim | None = None
    try:
        for level in plan:
            base = working if working is not None else AEFAddress()
            intended = replace(base, **{level: getattr(addr, level)})
            allowed = admit(level, intended)
            emit(level, serialize(intended), "allow" if allowed else "deny")
            if not allowed:
                return result(
                    DENIED, res, materialized,
                    reason=f"admission check denied {level} provisioning (S5)",
                )
            if level == "session" and claim is None:
                if intended.project is None:
                    raise ProvisionError(
                        "session provisioning needs project= — a session "
                        "is bound to a project path (D2), and the D7 "
                        "write-claim anchors there"
                    )
                claim = WriteClaim(
                    intended.project,
                    holder=claim_holder or "aef-resolve:provision",
                )
                if not claim.acquire(timeout=claim_timeout):
                    raise WriteClaimHeld(
                        f"project write-claim held by {claim.current()!r}; "
                        "session provisioning mutates fabric and writes "
                        "serialize (D7)"
                    )
            provisioner = provisioners.get(level)
            if provisioner is None:
                raise ProvisionError(f"no provisioner for level {level!r}")
            produced = provisioner(intended)
            working = produced if produced is not None else intended
            if getattr(working, level) is None:
                raise ProvisionError(
                    f"{level} provisioner returned an address without "
                    f"{level}= — nothing was materialized"
                )
            materialized.append(serialize(working))
        return result(PROVISIONED, res, materialized)
    finally:
        if claim is not None:
            claim.release()
