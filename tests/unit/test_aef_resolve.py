"""T-3309 (arc-020 S3): tests for the resolution + provisioning ladder.

Spec: docs/reports/T-3287-identity-taxonomy-circuit-model.md (D1, D4, D5, D7).
Covers: the full 5->1 resolve walk (found at each level), the
definitive-vs-indeterminate tri-state (the S2 Evolution handoff), resolve
side-effect-freeness, top-down materialization of exactly the missing
suffix, the hub-standup authorization ceiling, D7 write-claim
acquire-before-mutate + release, the missing-project-path S6 halt, and the
S5 admission / S7 audit seams.
"""

from __future__ import annotations

import sys
from dataclasses import replace
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.aef_address import AEFAddress, parse, serialize  # noqa: E402
from lib.aef_circuit import CircuitRegistry, WriteClaim  # noqa: E402
from lib.aef_resolve import (  # noqa: E402
    ALREADY_EXISTS,
    DENIED,
    FOUND,
    HALTED,
    HANDOFF_S6,
    INDETERMINATE,
    NOT_FOUND,
    PROVISIONED,
    REFUSED,
    ProvisionError,
    ResolveIndeterminate,
    death_test_walk,
    provision,
    resolve,
)

CIRCUIT = (
    "aef::host=host107.ring20.lan::hub=H-1"
    "::project={project}::session=S-8f3c::@reviewer::"
)


def circuit(project: str) -> AEFAddress:
    return parse(CIRCUIT.format(project=project))


def probe_knowing(*existing: AEFAddress):
    """Probe that answers True for exactly the given rungs, logging calls."""
    known = {serialize(a) for a in existing}
    log: list[str] = []

    def probe(addr: AEFAddress) -> bool:
        log.append(serialize(addr))
        return serialize(addr) in known

    probe.log = log
    return probe


# ── resolve: the full 5->1 walk ──────────────────────────────────────────


def test_resolve_finds_endpoint_at_each_level(tmp_path):
    """Walking 5->1: whichever rung exists first is where the walk lands."""
    target = circuit(str(tmp_path))
    rungs = target.ladder()  # [full, -agent, -session, -project, host-only]
    assert len(rungs) == 5
    for i, rung in enumerate(rungs):
        probe = probe_knowing(rung)
        result = resolve(target, probe)
        assert result.is_definitive
        assert result.outcome == (FOUND if i == 0 else NOT_FOUND)
        assert result.found_at == serialize(rung)
        # exactly the rungs deeper than the found one are missing, top-down
        assert result.missing == tuple(
            serialize(r) for r in reversed(rungs[:i])
        )
        # the walk stopped at the found rung — no probes above it
        assert probe.log == [serialize(r) for r in rungs[: i + 1]]


def test_resolve_nothing_found_is_still_definitive(tmp_path):
    """Even the host absent: the walk COMPLETED, so the answer is definitive."""
    target = circuit(str(tmp_path))
    result = resolve(target, probe_knowing())
    assert result.outcome == NOT_FOUND
    assert result.is_definitive
    assert result.found_at is None
    assert len(result.missing) == 5


def test_resolve_probe_error_is_indeterminate(tmp_path):
    """A raising probe means COULD NOT WALK — never a not-found (D4-A)."""
    target = circuit(str(tmp_path))

    def probe(addr):
        raise TimeoutError("host unreachable")

    result = resolve(target, probe)
    assert result.outcome == INDETERMINATE
    assert not result.is_definitive
    assert result.found_at is None
    assert result.missing == ()
    assert "host unreachable" in result.error
    assert result.trail[-1].outcome == "error"


def test_death_test_walk_honours_s2_contract(tmp_path):
    """The adapter feeds CircuitRegistry.death_test: found=True,
    definitive-absent=False (kills), indeterminate=raise (state untouched)."""
    target = circuit(str(tmp_path))
    assert death_test_walk(probe_knowing(target))(target) is True
    assert death_test_walk(probe_knowing())(target) is False

    def broken(addr):
        raise OSError("network down")

    with pytest.raises(ResolveIndeterminate):
        death_test_walk(broken)(target)

    # end-to-end with the real S2 registry: indeterminate never kills
    registry = CircuitRegistry(tmp_path)
    record = registry.establish(target)
    with pytest.raises(ResolveIndeterminate):
        registry.death_test(record.circuit_id, death_test_walk(broken))
    assert registry.get(record.circuit_id).state != "dead"
    killed = registry.death_test(record.circuit_id, death_test_walk(probe_knowing()))
    assert killed.state == "dead"


def test_resolve_is_side_effect_free(tmp_path):
    """Resolve calls the probe and NOTHING else — no files, no writes (D5)."""
    target = circuit(str(tmp_path / "proj"))
    before = sorted(p for p in tmp_path.rglob("*"))
    probe = probe_knowing()
    result = resolve(target, probe)
    after = sorted(p for p in tmp_path.rglob("*"))
    assert before == after  # filesystem untouched
    assert result.outcome == NOT_FOUND
    assert len(probe.log) == 5  # the probe trail is the only trace


# ── provision: shared skeleton, top-down materialization ─────────────────


def make_provisioners(calls: list[tuple[str, str]] | None = None):
    """Stub provisioners for every level; session mints a fresh id (D1)."""
    calls = calls if calls is not None else []

    def make(level):
        def prov(intended: AEFAddress) -> AEFAddress | None:
            out = (
                replace(intended, session="S-fresh")
                if level == "session" and intended.session is None
                else None
            )
            calls.append((level, serialize(out if out is not None else intended)))
            return out

        return prov

    provs = {lvl: make(lvl) for lvl in ("hub", "project", "session", "agent")}
    return provs, calls


def test_provision_materializes_exactly_the_missing_suffix(tmp_path):
    """Found at hub level -> materialize project, session, agent — top-down."""
    proj = tmp_path / "proj"
    proj.mkdir()
    target = circuit(str(proj))
    rungs = target.ladder()
    provs, calls = make_provisioners()
    result = provision(target, probe_knowing(rungs[3]), provs)  # host+hub exist
    assert result.outcome == PROVISIONED
    assert [lvl for lvl, _ in calls] == ["project", "session", "agent"]
    # descent ends at the full target address
    assert result.materialized[-1] == serialize(target)
    assert len(result.materialized) == 3


def test_provision_found_endpoint_materializes_nothing(tmp_path):
    target = circuit(str(tmp_path))
    provs, calls = make_provisioners()
    result = provision(target, probe_knowing(target), provs)
    assert result.outcome == ALREADY_EXISTS
    assert result.materialized == ()
    assert calls == []


def test_provision_indeterminate_resolve_provisions_nothing(tmp_path):
    """Acting on an unwalkable world would smuggle timeout-death back in."""
    target = circuit(str(tmp_path))
    provs, calls = make_provisioners()

    def broken(addr):
        raise TimeoutError("probe timeout")

    result = provision(target, broken, provs)
    assert result.outcome == INDETERMINATE
    assert result.materialized == ()
    assert calls == []


def test_provision_mints_fresh_session_for_durable_target(tmp_path):
    """A durable (session-less) target still gets a hosting session (D1:
    a working equivalent under a NEW id, never a resurrection)."""
    proj = tmp_path / "proj"
    proj.mkdir()
    target = circuit(str(proj)).to_durable()
    provs, calls = make_provisioners()
    # host+hub+project exist; agent needs a session even though the
    # durable address carries no session= token
    found = AEFAddress(host=target.host, hub=target.hub, project=target.project)
    result = provision(target, probe_knowing(found), provs)
    assert result.outcome == PROVISIONED
    assert [lvl for lvl, _ in calls] == ["session", "agent"]
    assert "session=S-fresh" in result.materialized[-1]


def test_provision_refused_below_hub_standup_authorization(tmp_path):
    """No reachable host: standing up a HOST exceeds the Tier-3 ceiling (D5)."""
    proj = tmp_path / "proj"
    proj.mkdir()
    target = circuit(str(proj))
    provs, calls = make_provisioners()
    result = provision(target, probe_knowing(), provs)  # nothing exists
    assert result.outcome == REFUSED
    assert result.materialized == ()
    assert calls == []
    assert "hub-standup" in result.reason
    assert result.audit[-1]["decision"] == "refused"


def test_provision_hub_standup_itself_is_authorized(tmp_path):
    """The ceiling is INCLUSIVE of hub-standup: host exists -> hub may go up."""
    proj = tmp_path / "proj"
    proj.mkdir()
    target = circuit(str(proj))
    provs, calls = make_provisioners()
    host_only = AEFAddress(host=target.host)
    result = provision(target, probe_knowing(host_only), provs)
    assert result.outcome == PROVISIONED
    assert [lvl for lvl, _ in calls] == ["hub", "project", "session", "agent"]


def test_missing_project_path_halts_with_s6_signal(tmp_path):
    """The ladder never creates project paths (D5 bound 3): halt, hand to S6."""
    target = circuit(str(tmp_path / "not-on-disk"))
    provs, calls = make_provisioners()
    host_hub = AEFAddress(host=target.host, hub=target.hub)
    result = provision(target, probe_knowing(host_hub), provs)
    assert result.outcome == HALTED
    assert result.handoff == HANDOFF_S6
    assert result.materialized == ()
    assert calls == []
    assert result.audit[-1]["decision"] == "halted"
    # injectable path check is honored (the seam, not just the default)
    result2 = provision(
        target, probe_knowing(host_hub), provs, path_exists=lambda p: True
    )
    assert result2.outcome == PROVISIONED


def test_session_provision_acquires_and_releases_write_claim(tmp_path):
    """D7: the project write-claim is held BEFORE the session fabric
    mutation and released when the descent ends."""
    proj = tmp_path / "proj"
    proj.mkdir()
    target = circuit(str(proj))
    claim_path = WriteClaim(proj).path
    held_during: list[tuple[str, bool]] = []

    def make(level):
        def prov(intended):
            held_during.append((level, claim_path.exists()))
            if level == "session" and intended.session is None:
                return replace(intended, session="S-fresh")
            return None

        return prov

    provs = {lvl: make(lvl) for lvl in ("project", "session", "agent")}
    found = AEFAddress(host=target.host, hub=target.hub)
    result = provision(target, probe_knowing(found), provs)
    assert result.outcome == PROVISIONED
    # claim not yet held for the project step; held for session AND agent
    assert held_during == [
        ("project", False),
        ("session", True),
        ("agent", True),
    ]
    assert not claim_path.exists()  # released after the descent


def test_write_claim_released_even_when_provisioner_raises(tmp_path):
    proj = tmp_path / "proj"
    proj.mkdir()
    target = circuit(str(proj))
    claim_path = WriteClaim(proj).path

    def boom(intended):
        raise RuntimeError("provisioner crashed")

    provs, _ = make_provisioners()
    provs["agent"] = boom
    found = AEFAddress(host=target.host, hub=target.hub, project=target.project)
    with pytest.raises(RuntimeError):
        provision(target, probe_knowing(found), provs)
    assert not claim_path.exists()


# ── seams: S5 admission check + S7 audit sink ────────────────────────────


def test_admission_check_consulted_per_decision_and_deny_blocks(tmp_path):
    proj = tmp_path / "proj"
    proj.mkdir()
    target = circuit(str(proj))
    provs, calls = make_provisioners()
    consulted: list[str] = []

    def admission(level, intended):
        consulted.append(level)
        return level != "agent"  # governor denies the last step

    found = AEFAddress(host=target.host, hub=target.hub)
    result = provision(target, probe_knowing(found), provs, admission=admission)
    assert result.outcome == DENIED
    assert consulted == ["project", "session", "agent"]  # one consult per step
    assert [lvl for lvl, _ in calls] == ["project", "session"]  # deny blocked agent
    deny_rows = [r for r in result.audit if r["decision"] == "deny"]
    assert len(deny_rows) == 1 and deny_rows[0]["level"] == "agent"


def test_audit_row_emitted_per_provision_decision(tmp_path):
    """S7 seam: default collects on the result; a custom sink sees every row."""
    proj = tmp_path / "proj"
    proj.mkdir()
    target = circuit(str(proj))
    provs, _ = make_provisioners()
    found = AEFAddress(host=target.host, hub=target.hub)

    result = provision(target, probe_knowing(found), provs)
    assert [(r["level"], r["decision"]) for r in result.audit] == [
        ("project", "allow"),
        ("session", "allow"),
        ("agent", "allow"),
    ]
    assert all("ts" in r and "address" in r for r in result.audit)

    sink_rows: list[dict] = []
    result2 = provision(
        target, probe_knowing(found), provs, audit_sink=sink_rows.append
    )
    assert sink_rows == list(result2.audit)


def test_provision_target_needs_host():
    with pytest.raises(ProvisionError):
        provision(parse("aef::hub=H-1::@reviewer::"), probe_knowing(), {})


def test_missing_provisioner_is_an_error(tmp_path):
    proj = tmp_path / "proj"
    proj.mkdir()
    target = circuit(str(proj))
    found = AEFAddress(host=target.host, hub=target.hub, project=target.project)
    with pytest.raises(ProvisionError):
        provision(target, probe_knowing(found), {})
