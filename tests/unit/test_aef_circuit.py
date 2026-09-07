"""T-3308 (arc-020 S2): tests for the circuit registry + three-state lifecycle.

Spec: docs/reports/T-3287-identity-taxonomy-circuit-model.md (D1, D4-A/B/C, D7).
Covers: registry CRUD + persistence round-trip, all three states + legal
transitions, dormant reactivate-without-rediscovery, dead-only-by-resolve-walk
(with the timeout-alone-does-NOT-kill control), reconnect re-plug into the
latest project-durable fabric, and write-claim serialization.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.aef_address import parse, serialize  # noqa: E402
from lib.aef_circuit import (  # noqa: E402
    DEAD,
    DORMANT,
    LIVE,
    CircuitError,
    CircuitRegistry,
    IllegalTransition,
    ReactivationUnavailable,
    WriteClaim,
    WriteClaimHeld,
)

CIRCUIT = (
    "aef::host=host107.ring20.lan::hub=H-1"
    "::project={project}::session=S-8f3c::@reviewer::"
)
DURABLE = (
    "aef::host=host107.ring20.lan::hub=H-1"
    "::project={project}::@reviewer::"
)


@pytest.fixture
def root(tmp_path):
    return tmp_path


@pytest.fixture
def registry(root):
    # claim_timeout=0 so a contested claim surfaces immediately in tests
    return CircuitRegistry(root, claim_timeout=0.0)


def circuit_id(root, session="S-8f3c", agent="reviewer"):
    return (
        f"aef::host=host107.ring20.lan::hub=H-1"
        f"::project={root}::session={session}::@{agent}::"
    )


def establish(registry, root, **kw):
    return registry.establish(circuit_id(root, **kw))


PROFILES = {"S-8f3c": ["reviewer", "coder"]}


# ── CRUD + persistence round-trip ────────────────────────────────────────


class TestRegistryCrudAndPersistence:
    def test_establish_records_live_circuit(self, registry, root):
        record = establish(registry, root)
        assert record.state == LIVE
        assert record.circuit_id == circuit_id(root)
        # durable id is the correspondent: same address minus session=
        assert record.durable_id == serialize(parse(record.circuit_id).to_durable())
        assert "session=" not in record.durable_id

    def test_get_and_list(self, registry, root):
        a = establish(registry, root, session="S-1")
        b = establish(registry, root, session="S-2")
        registry.mark_dormant(b.circuit_id)
        assert registry.get(a.circuit_id).state == LIVE
        assert registry.get("aef::host=x::project=/p::session=S::@a::") is None
        assert {r.circuit_id for r in registry.list()} == {
            a.circuit_id,
            b.circuit_id,
        }
        assert [r.circuit_id for r in registry.list(state=DORMANT)] == [
            b.circuit_id
        ]

    def test_persistence_roundtrip_fresh_instance(self, registry, root):
        a = establish(registry, root, session="S-1")
        b = establish(registry, root, session="S-2")
        registry.mark_dormant(b.circuit_id)
        reloaded = CircuitRegistry(root)
        assert reloaded.get(a.circuit_id) == registry.get(a.circuit_id)
        assert reloaded.get(b.circuit_id).state == DORMANT
        # JSONL replay is last-write-wins: the file holds history, the
        # registry surfaces only the current record per circuit id
        lines = (root / ".context/circuits/registry.jsonl").read_text().splitlines()
        assert len(lines) == 3  # 2 establishes + 1 transition
        assert all(json.loads(line) for line in lines)

    def test_establish_refuses_durable_form(self, registry, root):
        with pytest.raises(CircuitError, match="session="):
            registry.establish(DURABLE.format(project=root))

    def test_establish_refuses_missing_levels(self, registry, root):
        # a circuit reaches a specific agent-instance in a specific project
        with pytest.raises(CircuitError, match="agent"):
            registry.establish(
                f"aef::host=h::project={root}::session=S-1::"
            )
        with pytest.raises(CircuitError, match="project"):
            registry.establish("aef::host=h::session=S-1::@reviewer::")

    def test_establish_refuses_duplicate_id(self, registry, root):
        establish(registry, root)
        with pytest.raises(CircuitError, match="NEW circuit id"):
            establish(registry, root)

    def test_hub_is_optional_d6(self, registry, root):
        record = registry.establish(
            f"aef::host=h::project={root}::session=S-9::@reviewer::"
        )
        assert record.state == LIVE


# ── three states + legal transitions ─────────────────────────────────────


class TestLifecycle:
    def test_live_to_dormant_and_back(self, registry, root):
        record = establish(registry, root)
        dormant = registry.mark_dormant(record.circuit_id)
        assert dormant.state == DORMANT
        result = registry.reactivate(record.circuit_id, PROFILES)
        assert result.record.state == LIVE

    def test_mark_dormant_is_idempotent(self, registry, root):
        record = establish(registry, root)
        registry.mark_dormant(record.circuit_id)
        assert registry.mark_dormant(record.circuit_id).state == DORMANT

    def test_live_and_dormant_can_die_by_walk(self, registry, root):
        a = establish(registry, root, session="S-1")
        b = establish(registry, root, session="S-2")
        registry.mark_dormant(b.circuit_id)
        assert registry.death_test(a.circuit_id, lambda addr: False).state == DEAD
        assert registry.death_test(b.circuit_id, lambda addr: False).state == DEAD

    def test_dead_is_terminal(self, registry, root):
        record = establish(registry, root)
        registry.death_test(record.circuit_id, lambda addr: False)
        with pytest.raises(IllegalTransition, match="terminal"):
            registry.reactivate(record.circuit_id, PROFILES)
        with pytest.raises(IllegalTransition):
            registry.mark_dormant(record.circuit_id)
        # re-running the death test on a proven-dead circuit is idempotent
        assert (
            registry.death_test(record.circuit_id, lambda addr: False).state
            == DEAD
        )


# ── D4-B: dormant reactivate WITHOUT rediscovery ─────────────────────────


class TestReactivateFastPath:
    def test_reactivate_needs_only_the_profile_registry(self, registry, root):
        """The fast path consults the session's profile registry and nothing
        else — no resolver exists in this test's scope at all."""
        record = establish(registry, root)
        registry.mark_dormant(record.circuit_id)
        result = registry.reactivate(record.circuit_id, PROFILES)
        assert result.record.state == LIVE
        assert result.fast_path is True

    def test_bounded_by_profile_registry_unknown_session(self, registry, root):
        record = establish(registry, root)
        registry.mark_dormant(record.circuit_id)
        with pytest.raises(ReactivationUnavailable, match="not proof of death"):
            registry.reactivate(record.circuit_id, {})
        # unavailability is NOT death — the circuit stays dormant
        assert registry.get(record.circuit_id).state == DORMANT

    def test_bounded_by_profile_registry_missing_profile(self, registry, root):
        record = establish(registry, root)
        registry.mark_dormant(record.circuit_id)
        with pytest.raises(ReactivationUnavailable, match="@reviewer"):
            registry.reactivate(record.circuit_id, {"S-8f3c": ["coder"]})
        assert registry.get(record.circuit_id).state == DORMANT

    def test_profile_registry_may_be_callable(self, registry, root):
        record = establish(registry, root)
        registry.mark_dormant(record.circuit_id)
        result = registry.reactivate(
            record.circuit_id, lambda sid: ["reviewer"] if sid == "S-8f3c" else None
        )
        assert result.record.state == LIVE


# ── D4-A: dead ONLY by resolve-walk ──────────────────────────────────────


class TestDeathTest:
    def test_dead_only_via_failed_resolve_walk(self, registry, root):
        record = establish(registry, root)
        walked = []

        def resolve_walk(addr):
            walked.append(addr)
            return False  # walk completed; session not found

        assert registry.death_test(record.circuit_id, resolve_walk).state == DEAD
        # the walk received the retained address to descend (D4-A)
        assert walked[0] == parse(record.circuit_id)

    def test_successful_walk_keeps_state(self, registry, root):
        record = establish(registry, root)
        registry.mark_dormant(record.circuit_id)
        after = registry.death_test(record.circuit_id, lambda addr: True)
        assert after.state == DORMANT

    def test_timeout_alone_does_not_kill(self, registry, root):
        """The control: unreachable observations pile up, state never moves."""
        record = establish(registry, root)
        for _ in range(5):
            registry.record_unreachable(record.circuit_id, reason="timeout")
        after = registry.get(record.circuit_id)
        assert after.state == LIVE
        assert after.unreachable_count == 5

    def test_walk_that_raises_is_inconclusive(self, registry, root):
        """A walk that errors out (e.g. times out) proves nothing: the
        exception propagates and the circuit is untouched."""
        record = establish(registry, root)

        def timing_out_walk(addr):
            raise TimeoutError("host unreachable")

        with pytest.raises(TimeoutError):
            registry.death_test(record.circuit_id, timing_out_walk)
        assert registry.get(record.circuit_id).state == LIVE

    def test_no_other_route_into_dead(self, registry, root):
        record = establish(registry, root)
        with pytest.raises(IllegalTransition, match="resolve-walk"):
            registry._transition(
                registry.get(record.circuit_id), DEAD, via="timeout"
            )
        assert registry.get(record.circuit_id).state == LIVE


# ── D4-C: reconnect re-plugs into the LATEST project fabric ──────────────


class TestReconnectReplug:
    def test_replug_loads_latest_project_state(self, registry, root):
        """Fabric state is read at reconnect time — a write that happened
        while the profile was away is present in the resumed state."""
        state_file = root / ".context" / "working" / "agent-state.txt"
        state_file.parent.mkdir(parents=True, exist_ok=True)
        state_file.write_text("state-at-establish")

        def fabric(project_path):
            return (Path(project_path) / ".context/working/agent-state.txt").read_text()

        record = establish(registry, root)
        registry.mark_dormant(record.circuit_id)
        # the agent's project-durable state GROWS while dormant (D4/C)
        state_file.write_text("state-grown-while-dormant")
        result = registry.reactivate(record.circuit_id, PROFILES, fabric=fabric)
        assert result.fabric_state == "state-grown-while-dormant"

    def test_reconnect_on_live_circuit_replugs(self, registry, root):
        record = establish(registry, root)
        result = registry.reactivate(record.circuit_id, PROFILES)
        assert result.record.state == LIVE
        assert result.fast_path is True
        # default loader points at the circuit's own project context fabric
        # (which exists: the registry itself persists under .context/circuits/)
        assert result.fabric_state["project"] == str(root)
        assert result.fabric_state["context_dir"] == str(root / ".context")
        assert result.fabric_state["context_exists"] is True


# ── D7: write-claim serialization ────────────────────────────────────────


class TestWriteClaim:
    def test_two_writers_one_claim(self, root):
        a = WriteClaim(root, holder="writer-a")
        b = WriteClaim(root, holder="writer-b")
        assert a.acquire() is True
        assert b.acquire() is False  # contested: exactly one holder
        a.release()
        assert b.acquire() is True
        b.release()

    def test_registry_writes_serialize_through_claim(self, registry, root):
        other = WriteClaim(root, holder="other-writer")
        assert other.acquire() is True
        with pytest.raises(WriteClaimHeld, match="serialize"):
            establish(registry, root)
        other.release()
        assert establish(registry, root).state == LIVE

    def test_reads_fan_out_freely_while_claim_held(self, registry, root):
        record = establish(registry, root)
        other = WriteClaim(root, holder="other-writer")
        assert other.acquire() is True
        try:
            # reads never touch the claim (D7: fan out on reads)
            assert registry.get(record.circuit_id).state == LIVE
            assert len(registry.list()) == 1
        finally:
            other.release()

    def test_stale_claim_from_dead_pid_is_broken(self, root):
        proc = subprocess.Popen(["true"])
        proc.wait()  # reaped: the pid is gone
        claim_path = root / ".context" / "circuits" / ".write-claim"
        claim_path.parent.mkdir(parents=True, exist_ok=True)
        claim_path.write_text(
            json.dumps({"holder": "crashed", "pid": proc.pid, "ts": "x"})
        )
        fresh = WriteClaim(root, holder="writer-b")
        assert fresh.acquire() is True
        fresh.release()

    def test_context_manager(self, root):
        with WriteClaim(root, holder="a") as claim:
            assert claim.current()["holder"] == "a"
            with pytest.raises(WriteClaimHeld):
                with WriteClaim(root, holder="b"):
                    pass  # pragma: no cover
        assert WriteClaim(root).current() is None
