"""T-3310 (arc-020 S4): tests for claim-based election (exactly-one provisioning).

Spec: docs/reports/T-3287-identity-taxonomy-circuit-model.md (D5 bound 1,
Q-A, F5). Covers: exactly-one-wins under a genuine thread race, mutual
exclusion (first-claim-wins), clean loser backoff (single attempt, no
retry loop), release/TTL/stale-pid all returning the target to the
electable state, the injectable-backend shape (protocol + termlink stub),
and the integration leg — the winner routes into aef_resolve.provision
while losers never enter the walk (broadcast storm provisions ONE, not N).
"""

from __future__ import annotations

import json
import subprocess
import sys
import threading
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.aef_address import AEFAddress, parse, serialize  # noqa: E402
from lib.aef_election import (  # noqa: E402
    LOST,
    WON,
    ClaimBackend,
    ClaimTicket,
    ElectionError,
    ElectionResult,
    LocalClaimBackend,
    TermlinkChannelClaimBackend,
    elect,
    elect_and_provision,
    election_claim_path,
)
from lib.aef_resolve import ALREADY_EXISTS, PROVISIONED  # noqa: E402


def target_for(tmp_path: Path) -> AEFAddress:
    """A durable provisionable target: host + hub + on-disk project + @agent."""
    return AEFAddress(
        host="h1.lan", hub="hub-a", project=str(tmp_path), agent="worker"
    )


# ── mutual exclusion / first-claim-wins ──────────────────────────────────


def test_first_claim_wins_mutual_exclusion(tmp_path):
    backend = LocalClaimBackend(tmp_path)
    target = target_for(tmp_path)

    first = elect(target, "cand-a", backend)
    second = elect(target, "cand-b", backend)

    assert first.won and first.role == WON
    assert first.ticket is not None
    assert not second.won and second.role == LOST
    assert second.ticket is None
    assert second.holder["holder"] == "cand-a"  # loser learns who holds it
    first.release()


def test_elect_accepts_wire_string_and_address(tmp_path):
    backend = LocalClaimBackend(tmp_path)
    addr = target_for(tmp_path)
    wire = serialize(addr)

    won = elect(wire, "cand-a", backend)
    lost = elect(addr, "cand-b", backend)  # same target, either spelling

    assert won.won and won.target == wire
    assert not lost.won and lost.target == wire
    won.release()


def test_empty_candidate_id_refused(tmp_path):
    with pytest.raises(ElectionError):
        elect(target_for(tmp_path), "", LocalClaimBackend(tmp_path))


def test_distinct_targets_are_independent_elections(tmp_path):
    backend = LocalClaimBackend(tmp_path)
    a = elect(target_for(tmp_path), "cand-a", backend)
    other = AEFAddress(host="h2.lan", project=str(tmp_path), agent="other")
    b = elect(other, "cand-b", backend)
    assert a.won and b.won  # different targets: both electable
    a.release()
    b.release()


# ── exactly-one-wins under a genuine race ────────────────────────────────


def test_exactly_one_wins_under_thread_race(tmp_path):
    """N threads released by a barrier contend one target; exactly 1 wins."""
    n = 8
    target = target_for(tmp_path)
    barrier = threading.Barrier(n)
    results: list[ElectionResult] = []
    lock = threading.Lock()

    def candidate(i: int) -> None:
        backend = LocalClaimBackend(tmp_path)  # own backend, shared target
        barrier.wait()  # genuinely simultaneous attempts
        result = elect(target, f"cand-{i}", backend)
        with lock:
            results.append(result)

    threads = [threading.Thread(target=candidate, args=(i,)) for i in range(n)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    winners = [r for r in results if r.won]
    losers = [r for r in results if not r.won]
    assert len(winners) == 1
    assert len(losers) == n - 1
    # every loser saw the one winner as the holder
    assert {r.holder["holder"] for r in losers} == {winners[0].candidate_id}
    winners[0].release()


# ── loser backoff is clean ───────────────────────────────────────────────


def test_loser_backoff_is_single_attempt_no_retry(tmp_path):
    backend = LocalClaimBackend(tmp_path)
    target = target_for(tmp_path)
    winner = elect(target, "cand-a", backend)

    started = time.monotonic()
    loser = elect(target, "cand-b", backend)
    elapsed = time.monotonic() - started

    assert not loser.won
    assert elapsed < 0.5  # no polling loop, no sleep — one attempt and out
    # the winner's claim is untouched by the losing attempt
    assert backend.holder(loser.target)["holder"] == "cand-a"
    with pytest.raises(ElectionError):
        loser.release()  # a loser holds nothing to release
    winner.release()


# ── release / expiry return the target to the electable state ────────────


def test_release_returns_target_electable(tmp_path):
    backend = LocalClaimBackend(tmp_path)
    target = target_for(tmp_path)

    first = elect(target, "cand-a", backend)
    assert first.won
    first.release()
    assert first.ticket.released

    second = elect(target, "cand-b", backend)
    assert second.won  # released target is electable again
    second.release()


def test_stale_dead_pid_claim_is_broken(tmp_path):
    """A crashed winner (dead pid) does not hold the target forever (S2 leg)."""
    target = target_for(tmp_path)
    wire = serialize(target)
    dead = subprocess.Popen(["true"])
    dead.wait()  # reaped: the pid is definitely gone
    path = election_claim_path(tmp_path, wire)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            {"holder": "crashed", "pid": dead.pid, "ts": "2026-01-01T00:00:00Z"}
        )
    )

    result = elect(target, "cand-b", LocalClaimBackend(tmp_path))
    assert result.won  # stale claim broken, target was electable
    assert result.holder["holder"] == "cand-b"
    result.release()


def test_ttl_expiry_breaks_hung_live_pid_claim(tmp_path):
    """TTL breaks a claim whose holder pid is alive but hung."""
    target = target_for(tmp_path)
    holder = elect(target, "cand-a", LocalClaimBackend(tmp_path))
    assert holder.won  # live pid (ours), never released

    fresh = elect(target, "cand-b", LocalClaimBackend(tmp_path, ttl=3600))
    assert not fresh.won  # within TTL: still held

    expired = elect(target, "cand-c", LocalClaimBackend(tmp_path, ttl=0))
    assert expired.won  # past TTL: electable despite the live pid
    expired.release()


# ── injectable backend shape ─────────────────────────────────────────────


def test_local_backend_satisfies_claim_backend_protocol(tmp_path):
    backend = LocalClaimBackend(tmp_path)
    assert isinstance(backend, ClaimBackend)
    ticket = backend.try_claim("aef::host=h::@x::", "cand-a")
    assert isinstance(ticket, ClaimTicket)
    ticket.release()


def test_termlink_backend_is_shape_only(tmp_path):
    """The termlink adapter pins the protocol shape; wiring is deferred."""
    backend = TermlinkChannelClaimBackend(channel="aef-elections")
    assert isinstance(backend, ClaimBackend)
    with pytest.raises(NotImplementedError):
        backend.try_claim("aef::host=h::@x::", "cand-a")
    with pytest.raises(NotImplementedError):
        backend.holder("aef::host=h::@x::")


def test_custom_backend_is_honored(tmp_path):
    """elect() speaks only the protocol — any conforming double works."""

    class Ticket:
        def release(self):
            pass

    class AlwaysLost:
        def try_claim(self, target_wire, candidate_id):
            return None

        def holder(self, target_wire):
            return {"holder": "someone-else"}

    result = elect(target_for(tmp_path), "cand-a", AlwaysLost())
    assert not result.won
    assert result.holder == {"holder": "someone-else"}


# ── integration: winner provisions, losers never enter the walk ──────────


class World:
    """A tiny shared world for probe/provisioners; durable-form membership."""

    def __init__(self, tmp_path: Path):
        self.tmp_path = tmp_path
        base = AEFAddress(host="h1.lan")
        self.existing = {serialize(base)}
        self.calls: list[str] = []  # every provisioner invocation, by level

    def probe(self, addr: AEFAddress) -> bool:
        return serialize(addr.to_durable()) in self.existing

    def provisioners(self):
        def make(level):
            def run(intended: AEFAddress) -> AEFAddress | None:
                self.calls.append(level)
                produced = (
                    intended.to_circuit(f"s-{len(self.calls)}")
                    if level == "session"
                    else intended
                )
                self.existing.add(serialize(produced.to_durable()))
                return produced

            return run

        return {lv: make(lv) for lv in ("hub", "project", "session", "agent")}


def test_winner_provisions_loser_does_not(tmp_path):
    backend = LocalClaimBackend(tmp_path)
    target = target_for(tmp_path)
    world = World(tmp_path)

    winner = elect_and_provision(
        target, "cand-a", backend, world.probe, world.provisioners(),
        release_on_completion=False,
    )
    assert winner.won
    assert winner.provision.outcome == PROVISIONED
    assert world.calls == ["hub", "project", "session", "agent"]

    loser = elect_and_provision(
        target, "cand-b", backend, world.probe, world.provisioners()
    )
    assert not loser.won
    assert loser.provision is None  # the walk was never entered
    assert world.calls == ["hub", "project", "session", "agent"]  # unchanged

    winner.release()


def test_winner_releases_on_completion_by_default(tmp_path):
    backend = LocalClaimBackend(tmp_path)
    target = target_for(tmp_path)
    world = World(tmp_path)

    result = elect_and_provision(
        target, "cand-a", backend, world.probe, world.provisioners()
    )
    assert result.won and result.provision.outcome == PROVISIONED
    assert backend.holder(result.target) is None  # released on completion
    # and released even when the walk raises (crash-release). A crashing
    # PROBE is swallowed into INDETERMINATE by S3 design (D4-A), so the
    # crash has to happen in a provisioner:
    crashed_target = AEFAddress(host="h1.lan", project=str(tmp_path), agent="z")
    provs = world.provisioners()
    provs["project"] = lambda intended: (_ for _ in ()).throw(
        RuntimeError("provisioner crashed")
    )
    with pytest.raises(RuntimeError):
        elect_and_provision(
            crashed_target, "cand-c", backend, world.probe, provs
        )
    assert elect(crashed_target, "cand-d", backend).won  # electable again


def test_race_broadcast_storm_provisions_one_not_n(tmp_path):
    """N concurrent elect_and_provision calls: exactly one PROVISIONED.

    The claim is held across the walk, so contenders serialize; anyone
    winning after the first completion resolves ALREADY_EXISTS and
    materializes nothing (ensure-exists, D5 bound 1).
    """
    n = 6
    target = target_for(tmp_path)
    world = World(tmp_path)
    barrier = threading.Barrier(n)
    results: list[ElectionResult] = []
    lock = threading.Lock()

    def candidate(i: int) -> None:
        backend = LocalClaimBackend(tmp_path)
        barrier.wait()
        result = elect_and_provision(
            target, f"cand-{i}", backend, world.probe, world.provisioners()
        )
        with lock:
            results.append(result)

    threads = [threading.Thread(target=candidate, args=(i,)) for i in range(n)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    provisioned = [
        r for r in results if r.provision and r.provision.outcome == PROVISIONED
    ]
    losers = [r for r in results if not r.won]
    idle_winners = [
        r
        for r in results
        if r.won and r.provision and r.provision.outcome == ALREADY_EXISTS
    ]
    assert len(provisioned) == 1  # the storm provisioned ONE, not N
    assert len(losers) + len(idle_winners) == n - 1
    for r in losers:
        assert r.provision is None
    # each level materialized exactly once, fleet-wide
    assert world.calls == ["hub", "project", "session", "agent"]
