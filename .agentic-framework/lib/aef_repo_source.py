"""T-3312 (arc-020 S6): fleet repo-source + integrity verify.

The handoff target for the S3 provisioning ladder's D5 bound 3 halt
(lib/aef_resolve.py — provision() returns HALTED with handoff="S6" when a
project's path is not on disk, and never creates the path itself). This
module sources the missing repo from KNOWN fleet peers, integrity-verifies
it, and hands control back to the ladder. Ratified in
docs/reports/T-3287-identity-taxonomy-circuit-model.md (D5 bound 3):

  - KNOWN-FLEET-ONLY (never arbitrary network): the ONLY peers this module
    will ever talk to are the ones in the explicit ``fleet_peers`` list the
    caller passes in. The module constructs no peer names, resolves no
    discovery service, and queries each listed peer at most once, in order.
    Pinned by tests on the query log.
  - INTEGRITY BEFORE EXECUTION: a fetched repo artifact must pass sha256
    verification against an expected digest — from a trusted manifest
    (``expected_sha256``, which takes precedence) or from the peer's own
    answer — BEFORE anything from it may be materialized or run. A missing
    digest is a verification failure, not a pass. A failed verification
    aborts that peer's artifact without executing it and records which
    peer and which digests (expected vs actual) failed.
  - UNFINDABLE IS SURFACED, NEVER SILENT: when no peer has the repo (or
    every offered artifact fails verification), sourcing halts and the
    operator is informed through a structured OperatorNotice, delivered
    via an injectable notice-sink (default: one line to stderr + append
    to the module-level OPERATOR_NOTICES ledger). The notice also rides
    on the returned SourceResult regardless of sink.

Transport is a seam, not an implementation: ``query_peer`` (how a peer is
asked) and ``materialize`` (how a verified artifact becomes the project
path) are injectable callables — real termlink/ssh wiring is later work.
``stub_query_peer`` documents the protocol shape until then.

Pure stdlib.
"""

from __future__ import annotations

import hashlib
import sys
import time
from dataclasses import dataclass
from typing import Callable, Sequence

try:  # imported as lib.aef_repo_source (test convention) or standalone
    from . import aef_resolve
    from .aef_resolve import HALTED, HANDOFF_S6, ProvisionResult
except ImportError:  # pragma: no cover — lib/ directly on sys.path
    import aef_resolve
    from aef_resolve import HALTED, HANDOFF_S6, ProvisionResult

# ── sourcing outcomes ────────────────────────────────────────────────────
SOURCED = "sourced"  # a peer's artifact verified and was materialized
UNFINDABLE = "unfindable"  # no peer had it / nothing verified — operator informed

# ── per-peer attempt outcomes (the audit trail of one sourcing run) ──────
NO_REPO = "no-repo"  # peer answered: does not have the repo
QUERY_ERROR = "query-error"  # asking the peer raised
FETCH_ERROR = "fetch-error"  # peer offered, fetching the artifact raised
NO_DIGEST = "no-digest"  # no expected digest anywhere — cannot verify, cannot run
DIGEST_MISMATCH = "digest-mismatch"  # sha256(artifact) != expected — aborted unrun
VERIFIED = "verified"  # sha256 matched; artifact may be materialized

#: In-process ledger the default notice-sink appends to, so a hosting
#: process can inspect every operator notice this module ever emitted.
OPERATOR_NOTICES: list["OperatorNotice"] = []


class RepoSourceError(Exception):
    """A sourcing run could not be set up (bad peers list, missing seam)."""


# ── records ──────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class PeerOffer:
    """A peer's positive answer to "do you have this repo?".

    ``fetch()`` returns the repo artifact bytes (archive/bundle — format
    is the materializer's business). ``sha256`` is the peer's claimed
    digest of that artifact; a trusted-manifest digest passed to
    source_repo() takes precedence over it.
    """

    peer: str
    fetch: Callable[[], bytes]
    sha256: str | None = None


@dataclass(frozen=True)
class SourceAttempt:
    """One peer consulted during a sourcing run, in query order."""

    peer: str
    outcome: str  # NO_REPO / QUERY_ERROR / FETCH_ERROR / NO_DIGEST / DIGEST_MISMATCH / VERIFIED
    expected_sha256: str | None = None
    actual_sha256: str | None = None
    error: str | None = None


@dataclass(frozen=True)
class OperatorNotice:
    """Structured "cannot start, human needed" signal (D5 bound 3)."""

    ts: str
    project: str
    peers_tried: tuple[str, ...]
    attempts: tuple[SourceAttempt, ...]
    message: str


@dataclass(frozen=True)
class SourceResult:
    """Outcome of one source_repo() run."""

    outcome: str  # SOURCED / UNFINDABLE
    project: str
    attempts: tuple[SourceAttempt, ...]
    peer: str | None = None  # the winning peer when SOURCED
    sha256: str | None = None  # the verified digest when SOURCED
    notice: OperatorNotice | None = None  # present when UNFINDABLE


@dataclass(frozen=True)
class LadderOutcome:
    """provision_with_sourcing()'s combined answer.

    ``sourcing`` is None when the ladder never halted on a missing path
    (sourcing was not needed); otherwise it is the SourceResult, and
    ``provision`` is the run taken AFTER sourcing succeeded — or the
    original halt when it did not.
    """

    provision: ProvisionResult
    sourcing: SourceResult | None = None


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


# ── the transport seams ──────────────────────────────────────────────────


def stub_query_peer(peer: str, project: str) -> PeerOffer | None:
    """Protocol stub for the peer-query seam (real termlink/ssh wiring is
    later work).

    Contract: ``query_peer(peer, project)`` asks ONE named peer whether it
    holds the repo for ``project``. Return a PeerOffer to say yes (with a
    fetch callable and, ideally, a claimed sha256), None to say no.
    Raising means the peer could not be asked — recorded as QUERY_ERROR
    and the run moves to the next known peer. The stub knows no transport,
    so it answers "no" for every peer.
    """
    return None


def default_notice_sink(notice: OperatorNotice) -> None:
    """Default operator-notice delivery: stderr + in-process ledger.

    Push-notification wiring (ntfy etc.) is deliberately NOT invented
    here — inject a sink that does that when the wiring exists.
    """
    OPERATOR_NOTICES.append(notice)
    print(f"[aef-repo-source] OPERATOR NOTICE: {notice.message}", file=sys.stderr)


DEFAULT_NOTICE_CHANNEL = "aef-operator-notices"


def _format_notice(notice: OperatorNotice) -> str:
    peers = ", ".join(notice.peers_tried) or "none"
    return (
        f"[AEF self-heal] cannot source repo for {notice.project!r}: "
        f"{notice.message} (peers tried: {peers})"
    )


def termlink_notice_sink(
    channel: str = DEFAULT_NOTICE_CHANNEL,
    invoke: Callable[..., dict] | None = None,
    *,
    also_default: bool = True,
) -> Callable[[OperatorNotice], None]:
    """T-3335 (arc-020 S8): wire the D5-bound-3 'inform operator' seam to a
    live termlink channel.

    Returns a ``notice_sink`` that posts the operator notice to a durable
    termlink channel (``aef-operator-notices`` by default) so the halt is
    visible fleet-wide, not only in one process's stderr.

    **Antifragile by construction:** the local delivery (``default_notice_sink``
    — the OPERATOR_NOTICES ledger + stderr) fires FIRST and unconditionally
    when ``also_default`` is set; the termlink post is strictly ADDITIONAL and
    best-effort. A termlink failure (hub down, binary missing) is itself logged
    to stderr and never suppresses the operator notice — a self-heal that
    cannot start must never fail silently because its *notification* channel
    was also down.

    Inject ``invoke`` in tests to exercise the post path with no live hub.
    """
    if invoke is None:
        try:  # lazy: keep this module loadable even if aef_election is not
            from .aef_election import default_termlink_invoke as _inv
        except ImportError:  # pragma: no cover — lib/ directly on sys.path
            from aef_election import default_termlink_invoke as _inv
        invoke = _inv

    def _sink(notice: OperatorNotice) -> None:
        if also_default:
            default_notice_sink(notice)
        body = _format_notice(notice)
        try:
            invoke(["channel", "create", channel])  # idempotent
            invoke(["channel", "post", channel, body, "--json"])
        except Exception as exc:  # best-effort — never mask the notice
            print(
                f"[aef-repo-source] termlink notice post failed: {exc}",
                file=sys.stderr,
            )

    return _sink


# ── the sourcing run: query -> fetch -> verify -> materialize ────────────


def source_repo(
    project: str,
    fleet_peers: Sequence[str],
    query_peer: Callable[[str, str], PeerOffer | None],
    materialize: Callable[[str, bytes], None],
    *,
    expected_sha256: str | None = None,
    notice_sink: Callable[[OperatorNotice], None] | None = None,
) -> SourceResult:
    """Source the repo for ``project`` from the KNOWN fleet peers.

    Queries exactly the peers in ``fleet_peers``, in order, stopping at
    the first peer whose artifact passes sha256 verification — that
    artifact (and no unverified byte before it) is handed to
    ``materialize(project, artifact)`` to become the missing path.
    ``expected_sha256`` is a trusted-manifest digest and takes precedence
    over any peer-claimed digest.

    When no peer yields a verified artifact, the run halts UNFINDABLE and
    informs the operator via ``notice_sink`` (default: stderr + the
    OPERATOR_NOTICES ledger). The notice names the project and every peer
    tried, with per-peer failure detail.
    """
    if isinstance(fleet_peers, (str, bytes)):
        raise RepoSourceError(
            "fleet_peers must be a sequence of peer names, not a single "
            "string — the known-peers list is explicit, never inferred"
        )
    if not callable(query_peer) or not callable(materialize):
        raise RepoSourceError("query_peer and materialize must be callables")

    peers = tuple(fleet_peers)
    attempts: list[SourceAttempt] = []

    for peer in peers:
        try:
            offer = query_peer(peer, project)
        except Exception as exc:
            attempts.append(SourceAttempt(peer, QUERY_ERROR, error=str(exc)))
            continue
        if offer is None:
            attempts.append(SourceAttempt(peer, NO_REPO))
            continue
        try:
            artifact = offer.fetch()
        except Exception as exc:
            attempts.append(SourceAttempt(peer, FETCH_ERROR, error=str(exc)))
            continue
        expected = expected_sha256 or offer.sha256
        if expected is None:
            attempts.append(
                SourceAttempt(
                    peer, NO_DIGEST,
                    error="no expected sha256 (peer claimed none, no trusted "
                    "manifest) — an unverifiable artifact may not run",
                )
            )
            continue
        expected = expected.lower()
        actual = hashlib.sha256(artifact).hexdigest()
        if actual != expected:
            attempts.append(
                SourceAttempt(
                    peer, DIGEST_MISMATCH,
                    expected_sha256=expected, actual_sha256=actual,
                    error=f"sha256 mismatch from peer {peer!r}: expected "
                    f"{expected}, got {actual} — artifact aborted unrun",
                )
            )
            continue
        # Verified — ONLY now may the artifact touch the project path.
        attempts.append(
            SourceAttempt(peer, VERIFIED, expected_sha256=expected, actual_sha256=actual)
        )
        materialize(project, artifact)
        return SourceResult(
            outcome=SOURCED,
            project=project,
            attempts=tuple(attempts),
            peer=peer,
            sha256=actual,
        )

    detail = "; ".join(
        f"{a.peer}: {a.outcome}" + (f" ({a.error})" if a.error else "")
        for a in attempts
    ) or "no known peers to ask"
    notice = OperatorNotice(
        ts=_now(),
        project=project,
        peers_tried=peers,
        attempts=tuple(attempts),
        message=(
            f"repo for project {project!r} is unfindable across "
            f"{len(peers)} known fleet peer(s) "
            f"[{', '.join(peers) or 'none'}] — provisioning cannot start; "
            f"operator action required. Detail: {detail}"
        ),
    )
    (notice_sink or default_notice_sink)(notice)
    return SourceResult(
        outcome=UNFINDABLE, project=project, attempts=tuple(attempts), notice=notice
    )


# ── handing back to the ladder ───────────────────────────────────────────


def provision_with_sourcing(
    target,
    probe,
    provisioners,
    *,
    fleet_peers: Sequence[str],
    query_peer: Callable[[str, str], PeerOffer | None],
    materialize: Callable[[str, bytes], None],
    expected_sha256: str | None = None,
    notice_sink: Callable[[OperatorNotice], None] | None = None,
    **provision_kwargs,
) -> LadderOutcome:
    """Run the S3 ladder; on a missing-path halt, fleet-source and resume.

    provision() halts with handoff="S6" when the project path is absent
    (it never creates paths — D5 bound 3). This wrapper is that handoff:
    it sources the repo from the known peers, and on success re-runs the
    SAME provision walk, which now finds the path on disk and descends
    normally. On UNFINDABLE the original halt is returned unchanged —
    with the operator already informed by source_repo().
    """
    first = aef_resolve.provision(target, probe, provisioners, **provision_kwargs)
    if first.outcome != HALTED or first.handoff != HANDOFF_S6:
        return LadderOutcome(provision=first)

    project = aef_resolve._as_address(target).project
    sourcing = source_repo(
        project,
        fleet_peers,
        query_peer,
        materialize,
        expected_sha256=expected_sha256,
        notice_sink=notice_sink,
    )
    if sourcing.outcome != SOURCED:
        return LadderOutcome(provision=first, sourcing=sourcing)

    second = aef_resolve.provision(target, probe, provisioners, **provision_kwargs)
    return LadderOutcome(provision=second, sourcing=sourcing)
