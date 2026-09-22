"""T-3433 — arc-011 sidecar circuit ids: derivation, forms, parsing."""

import importlib

import pytest


@pytest.fixture()
def mod(tmp_path, monkeypatch):
    project = tmp_path / "999-Agentic-Engineering-Framework"
    project.mkdir()
    monkeypatch.setenv("FRAMEWORK_ROOT", str(project))
    monkeypatch.setenv("FW_SIDECAR_HUB_ID", "cacc73ea32b121dd")
    monkeypatch.setenv("FW_SIDECAR_HOST", "host107.ring20.lan")
    monkeypatch.delenv("FW_SIDECAR_AGENT_ID", raising=False)
    monkeypatch.delenv("FW_FOCUS_SESSION_KEY", raising=False)
    monkeypatch.delenv("TERMLINK_SESSION", raising=False)
    import lib.sidecar.outbox as outbox
    import lib.sidecar.circuit as circuit
    importlib.reload(outbox)
    importlib.reload(circuit)
    return circuit


HUB = "cacc73ea32b121dd"
PROJ = "999-Agentic-Engineering-Framework"


# ── the levels ──────────────────────────────────────────────────────────────

def test_project_id_is_the_existing_basename_convention(mod, tmp_path):
    # lib/pickup.sh:42 — basename of PROJECT_ROOT. Not a second derivation.
    assert mod.project_id() == PROJ


def test_parent_session_with_no_agent_truncates_to_the_durable_role_address(mod):
    # No FW_SIDECAR_AGENT_ID, no session: the project-level address IS this
    # session's inbox, and that is correct rather than degraded.
    assert mod.circuit_id("agent") == f"{HUB}/{PROJ}"
    assert mod.circuit_id("project") == f"{HUB}/{PROJ}"


def test_dispatched_worker_collapses_session_and_agent(mod, monkeypatch):
    # The dispatch stanza exports both from one string; emitting it twice
    # would stop a peer deriving the same topic from the worker's name.
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "t3433-circuit-addr")
    monkeypatch.setenv("FW_FOCUS_SESSION_KEY", "t3433-circuit-addr")
    assert mod.circuit_id("agent") == f"{HUB}/{PROJ}/t3433-circuit-addr"
    # …and that is exactly what a peer addressing it by name derives.
    assert mod.resolve_address("t3433-circuit-addr") == f"{HUB}/{PROJ}/t3433-circuit-addr"


def test_distinct_session_keeps_all_four_address_levels(mod, monkeypatch):
    monkeypatch.setenv("TERMLINK_SESSION", "tl-8f3c")
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "reviewer")
    assert mod.circuit_id("agent") == f"{HUB}/{PROJ}/tl-8f3c/reviewer"


def test_termlink_session_wins_over_focus_session_key(mod, monkeypatch):
    monkeypatch.setenv("TERMLINK_SESSION", "tl-8f3c")
    monkeypatch.setenv("FW_FOCUS_SESSION_KEY", "focus-key")
    assert mod.session_id() == "tl-8f3c"


def test_full_form_is_host_qualified_and_agent_form_is_not(mod, monkeypatch):
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "reviewer")
    monkeypatch.setenv("FW_FOCUS_SESSION_KEY", "reviewer")
    assert mod.circuit_id("full") == f"//host107.ring20.lan/{HUB}/{PROJ}/reviewer"
    assert not mod.circuit_id("agent").startswith("//")


def test_unknown_level_is_refused(mod):
    with pytest.raises(ValueError):
        mod.circuit_id("planet")


# ── parsing ─────────────────────────────────────────────────────────────────

def test_parse_full_host_qualified_id(mod):
    got = mod.parse_circuit(f"//host107.ring20.lan/{HUB}/{PROJ}/tl-8f3c/reviewer")
    assert got == {"host": "host107.ring20.lan", "hub": HUB, "project": PROJ,
                   "session": "tl-8f3c", "agent": "reviewer"}


def test_parse_exact_agent_circuit_has_no_host(mod):
    got = mod.parse_circuit(f"{HUB}/{PROJ}/tl-8f3c/reviewer")
    assert got["host"] is None
    assert got["session"] == "tl-8f3c" and got["agent"] == "reviewer"


def test_parse_project_only_leaves_the_lower_levels_none(mod):
    got = mod.parse_circuit(f"{HUB}/{PROJ}")
    assert got["hub"] == HUB and got["project"] == PROJ
    assert got["session"] is None and got["agent"] is None and got["host"] is None


def test_parse_three_form_claims_an_agent_and_not_a_session(mod):
    # The collapsed dispatched-worker form asserts "this agent, under this
    # project" — it does NOT claim to know the session.
    got = mod.parse_circuit(f"{HUB}/{PROJ}/t3433-circuit-addr")
    assert got["agent"] == "t3433-circuit-addr"
    assert got["session"] is None


def test_parse_truncations_down_the_ladder(mod):
    assert mod.parse_circuit(HUB)["hub"] == HUB
    assert mod.parse_circuit(HUB)["project"] is None
    assert mod.parse_circuit("")["hub"] is None
    assert mod.parse_circuit("//host107.ring20.lan")["host"] == "host107.ring20.lan"


def test_parse_strips_either_topic_prefix(mod):
    assert mod.parse_circuit(f"inbox:{HUB}/{PROJ}")["project"] == PROJ
    assert mod.parse_circuit(f"sidecar:{HUB}/{PROJ}")["project"] == PROJ


def test_round_trip_every_emitted_form(mod, monkeypatch):
    monkeypatch.setenv("FW_SIDECAR_AGENT_ID", "reviewer")
    monkeypatch.setenv("TERMLINK_SESSION", "tl-8f3c")
    for level in ("project", "agent", "full"):
        cid = mod.circuit_id(level)
        parsed = mod.parse_circuit(cid)
        assert parsed["hub"] == HUB and parsed["project"] == PROJ
        assert parsed["host"] == ("host107.ring20.lan" if level == "full" else None)


# ── topics and address resolution ───────────────────────────────────────────

def test_topic_is_the_prefix_plus_the_circuit(mod):
    assert mod.topic_for_circuit(f"{HUB}/{PROJ}") == f"inbox:{HUB}/{PROJ}"


def test_topic_drops_the_host_because_a_topic_lives_on_a_hub(mod):
    assert mod.topic_for_circuit(f"//host107.ring20.lan/{HUB}/{PROJ}") == f"inbox:{HUB}/{PROJ}"


def test_bare_project_id_resolves_to_the_durable_role_address(mod):
    # 010-termlink is on another host and the same hub (measured 2026-09-22):
    # its address must not assert OUR fqdn.
    assert mod.resolve_address("010-termlink") == f"{HUB}/010-termlink"
    assert mod.topic_for_name("010-termlink") == f"inbox:{HUB}/010-termlink"


def test_bare_agent_name_resolves_under_our_project(mod):
    assert mod.resolve_address("e2e-ab947312-responder") == \
        f"{HUB}/{PROJ}/e2e-ab947312-responder"


def test_a_full_circuit_to_is_used_verbatim(mod):
    cid = f"{HUB}/003-NTB-ATC-Plugin/tl-9/reviewer"
    assert mod.resolve_address(cid) == cid
    assert mod.resolve_address(f"inbox:{cid}") == cid


def test_explicit_level_overrides_the_heuristic(mod):
    assert mod.resolve_address("010-termlink", level="agent") == \
        f"{HUB}/{PROJ}/010-termlink"
    assert mod.resolve_address("some-worker", level="project") == f"{HUB}/some-worker"


def test_is_project_id_signals(mod, tmp_path):
    assert mod.is_project_id(PROJ)                      # us
    assert mod.is_project_id("010-termlink")            # NNN- fleet convention
    assert not mod.is_project_id("e2e-ab947312-sender")
    assert not mod.is_project_id("t3433-circuit-addr")
    sibling = tmp_path / "some-consumer"
    sibling.mkdir()
    (sibling / ".framework.yaml").write_text("project_name: some-consumer\n")
    assert mod.is_project_id("some-consumer")           # sibling project dir


def test_empty_address_is_refused(mod):
    with pytest.raises(mod.CircuitError):
        mod.resolve_address("   ")


# ── the hub anchor ──────────────────────────────────────────────────────────

def test_hub_id_env_override_wins(mod):
    assert mod.hub_id() == HUB


def test_hub_id_reads_the_fingerprint_and_caches_it(mod, monkeypatch, tmp_path):
    monkeypatch.delenv("FW_SIDECAR_HUB_ID", raising=False)
    calls = []

    def runner(argv, **kw):
        calls.append(argv)
        return type("P", (), {"returncode": 0, "stdout": "sha256:" + "ab" * 32,
                              "stderr": ""})()

    assert mod.hub_id(runner=runner) == "ab" * 8
    assert mod.hub_id(runner=runner) == "ab" * 8
    assert len(calls) == 1                       # cached, not re-shelled
    assert (tmp_path / "999-Agentic-Engineering-Framework" / ".context"
            / "sidecar" / "hub-id").read_text().strip() == "ab" * 8


def test_unreadable_fingerprint_raises_rather_than_inventing_an_anchor(mod, monkeypatch):
    monkeypatch.delenv("FW_SIDECAR_HUB_ID", raising=False)
    mod._hub_cache = None

    def runner(argv, **kw):
        return type("P", (), {"returncode": 1, "stdout": "", "stderr": "no hub"})()

    with pytest.raises(mod.CircuitError):
        mod.hub_id(runner=runner)
