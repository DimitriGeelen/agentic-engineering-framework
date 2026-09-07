"""T-3307 (arc-020 S1): tests for the V9 address grammar library.

Spec: docs/reports/T-3287-identity-taxonomy-circuit-model.md (D3 + D6).
Covers: round-trip, correspondent<->actor split, display-only elision,
optional hub=, IPv6 bracketing both directions, V4 alias parity,
sparse/ladder token-drop.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.aef_address import (  # noqa: E402
    AddressError,
    AEFAddress,
    elide_path,
    parse,
    parse_v4,
    parse_v9,
    serialize,
)

# Worked examples straight from the charter (D3).
DURABLE = (
    "aef::host=host107.ring20.lan::hub=H-1"
    "::project=/opt/999-Agentic-Engineering-Framework::@reviewer::"
)
CIRCUIT = (
    "aef::host=host107.ring20.lan::hub=H-1"
    "::project=/opt/999-Agentic-Engineering-Framework::session=S-8f3c::@reviewer::"
)
V4_CIRCUIT = (
    "host=host107.ring20.lan hub=H-1"
    " project=/opt/999-Agentic-Engineering-Framework session=S-8f3c @reviewer"
)
LADDER_RUNG = "aef::host=host107.ring20.lan::hub=H-1::"
QUERY = "aef::hub=H-1::@reviewer::"
IPV6 = "aef::host=[fe80::1]::hub=H-1::@reviewer::"
DEEP_PATH = "/mnt/storage/clients/acme/repos/frontend/042-Web-App"


# ── round-trip: serialize(parse(x)) == x ─────────────────────────────────


@pytest.mark.parametrize(
    "wire", [DURABLE, CIRCUIT, LADDER_RUNG, QUERY, IPV6],
    ids=["durable", "circuit", "ladder-rung", "query", "ipv6"],
)
def test_round_trip(wire):
    assert serialize(parse(wire)) == wire


def test_parse_structured_fields():
    addr = parse(CIRCUIT)
    assert addr.host == "host107.ring20.lan"
    assert addr.hub == "H-1"
    assert addr.project == "/opt/999-Agentic-Engineering-Framework"
    assert addr.session == "S-8f3c"
    assert addr.agent == "reviewer"


# ── correspondent <-> actor split (D2/D3) ────────────────────────────────


def test_circuit_vs_durable_is_session_token():
    assert parse(CIRCUIT).is_circuit
    assert not parse(DURABLE).is_circuit


def test_dropping_session_token_yields_durable_name():
    assert parse(CIRCUIT).to_durable() == parse(DURABLE)
    assert serialize(parse(CIRCUIT).to_durable()) == DURABLE


def test_adding_session_yields_circuit_id():
    assert parse(DURABLE).to_circuit("S-8f3c") == parse(CIRCUIT)
    assert serialize(parse(DURABLE).to_circuit("S-8f3c")) == CIRCUIT


def test_to_circuit_rejects_empty_session():
    with pytest.raises(AddressError):
        parse(DURABLE).to_circuit("")


def test_two_instances_same_durable_are_distinct_actors():
    # The origin bug (G1): distinct instances must never collapse.
    a = parse(DURABLE).to_circuit("S-aaaa")
    b = parse(DURABLE).to_circuit("S-bbbb")
    assert a != b
    assert a.to_durable() == b.to_durable()


# ── display-only path elision (D3 sub-rule) ──────────────────────────────


def test_elide_path_deep_path_first_plus_last_two():
    # Charter's own worked example.
    assert elide_path(DEEP_PATH) == "/mnt/…/frontend/042-Web-App"


def test_elide_path_short_paths_unchanged():
    # Our own project (2 segments) is under the threshold.
    assert elide_path("/opt/999-Agentic-Engineering-Framework") == (
        "/opt/999-Agentic-Engineering-Framework"
    )
    assert elide_path("/a/b/c") == "/a/b/c"  # exactly 3: unchanged


def test_elide_path_four_segments_elided():
    assert elide_path("/a/b/c/d") == "/a/…/c/d"


def test_elision_marker_is_single_char_ellipsis_not_dotdot():
    out = elide_path(DEEP_PATH)
    assert "…" in out
    assert ".." not in out  # '..' collides with the parent-dir operator


def test_display_format_elides_project():
    addr = AEFAddress(host="h.lan", project=DEEP_PATH, agent="reviewer")
    disp = addr.display_format()
    assert "project=/mnt/…/frontend/042-Web-App" in disp
    assert DEEP_PATH not in disp


def test_wire_serializer_never_emits_elided_form():
    # Asserted directly per the AC: full path only on the wire.
    addr = AEFAddress(host="h.lan", project=DEEP_PATH, agent="reviewer")
    wire = serialize(addr)
    assert DEEP_PATH in wire
    assert "…" not in wire
    # And round-trip preserves the full path.
    assert parse(wire).project == DEEP_PATH


def test_wire_serializer_refuses_elided_project_value():
    # A collided display string must never re-enter the wire.
    elided = AEFAddress(host="h.lan", project="/mnt/…/frontend/042-Web-App")
    with pytest.raises(AddressError):
        serialize(elided)


def test_display_format_unchanged_for_short_project():
    addr = parse(DURABLE)
    assert addr.display_format() == DURABLE


# ── optional hub= with host-default resolution (D6) ──────────────────────


def test_hub_optional_on_parse():
    wire = (
        "aef::host=host107.ring20.lan"
        "::project=/opt/999-Agentic-Engineering-Framework::@reviewer::"
    )
    addr = parse(wire)
    assert addr.hub is None
    assert serialize(addr) == wire  # round-trips without inventing a hub


def test_effective_hub_prefers_own_token():
    assert parse(DURABLE).effective_hub("H-default") == "H-1"


def test_effective_hub_resolves_host_default_when_absent():
    addr = parse("aef::host=host107.ring20.lan::@reviewer::")
    assert addr.effective_hub("H-default") == "H-default"
    assert addr.effective_hub({"host107.ring20.lan": "H-map"}) == "H-map"
    assert addr.effective_hub(lambda host: f"H-of-{host}") == (
        "H-of-host107.ring20.lan"
    )
    assert addr.effective_hub() is None
    assert addr.effective_hub({"other.host": "H-x"}) is None


# ── IPv6 bracketing both directions ──────────────────────────────────────


def test_ipv6_unbracketed_on_parse():
    assert parse(IPV6).host == "fe80::1"


def test_ipv6_bracketed_on_serialize():
    addr = AEFAddress(host="fe80::1", hub="H-1", agent="reviewer")
    assert serialize(addr) == IPV6


def test_ipv4_and_fqdn_hosts_not_bracketed():
    assert serialize(AEFAddress(host="10.0.0.7", agent="x")) == (
        "aef::host=10.0.0.7::@x::"
    )
    assert parse("aef::host=10.0.0.7::@x::").host == "10.0.0.7"


def test_ipv6_unbalanced_bracket_rejected():
    with pytest.raises(AddressError):
        parse("aef::host=[fe80::1::@x::")


# ── V4 human alias parity ────────────────────────────────────────────────


def test_v4_alias_parses_to_same_tuple_as_v9():
    assert parse(V4_CIRCUIT) == parse(CIRCUIT)


def test_v4_durable_parity():
    v4 = (
        "host=host107.ring20.lan hub=H-1"
        " project=/opt/999-Agentic-Engineering-Framework @reviewer"
    )
    assert parse(v4) == parse(DURABLE)


def test_v4_ipv6_bracketed_and_unbracketed():
    assert parse_v4("host=[fe80::1] @reviewer").host == "fe80::1"
    # Space-separated form has no '::' terminator clash, so bare is legal too.
    assert parse_v4("host=fe80::1 @reviewer").host == "fe80::1"


def test_v4_normalizes_to_v9_wire():
    # Two forms, one address: the alias serializes to the canonical wire.
    assert serialize(parse(V4_CIRCUIT)) == CIRCUIT


# ── sparse / ladder token-drop ───────────────────────────────────────────


def test_sparse_query_any_token_droppable():
    addr = parse(QUERY)
    assert addr == AEFAddress(hub="H-1", agent="reviewer")
    assert addr.host is None and addr.project is None and addr.session is None


def test_ladder_walk_explicit():
    circuit = parse(CIRCUIT)
    walk = [serialize(r) for r in circuit.ladder()]
    assert walk == [
        CIRCUIT,
        # drop @agent -> ask the session
        "aef::host=host107.ring20.lan::hub=H-1"
        "::project=/opt/999-Agentic-Engineering-Framework::session=S-8f3c::",
        # drop session -> ask the project bridge
        "aef::host=host107.ring20.lan::hub=H-1"
        "::project=/opt/999-Agentic-Engineering-Framework::",
        # drop project -> ask the hub (the charter's ladder example)
        LADDER_RUNG,
        # drop hub -> ask the host (last rung)
        "aef::host=host107.ring20.lan::",
    ]


def test_climb_stops_at_host():
    assert AEFAddress(host="h.lan").climb() is None


def test_sparse_climb_drops_rightmost_present():
    # Query form: rightmost present token is the agent, then the hub.
    q = parse(QUERY)
    assert serialize(q.climb()) == "aef::hub=H-1::"
    assert q.climb().climb() is None  # hub was the last present token


# ── grammar errors ───────────────────────────────────────────────────────


@pytest.mark.parametrize(
    "bad",
    [
        "",  # empty
        "aef::",  # no tokens
        "aef::host=h.lan",  # unterminated token
        "aef::port=99::@x::",  # unknown label
        "aef::host=h.lan::host=h2.lan::@x::",  # duplicate label
        "aef::@x::host=h.lan::",  # token after leaf
        "aef::host=::@x::",  # empty value
        "aef::@::",  # empty agent name
        "aef::bareword::@x::",  # neither label=value nor @name
    ],
)
def test_malformed_addresses_rejected(bad):
    with pytest.raises(AddressError):
        parse_v9(bad) if bad.startswith("aef::") else parse(bad)


def test_serialize_empty_address_rejected():
    with pytest.raises(AddressError):
        serialize(AEFAddress())
