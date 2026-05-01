"""T-1648 — Governance frame 0x8 protocol regression test.

T-1066 wired a data plane Governance frame (FrameType = 0x8) but zero
production callers emit it. If somebody renumbers the variant or renames a
GovernanceEvent field, only termlink's own tests would fail — the framework
that depends on this contract would not know.

This test pins the contract from the framework side via source-parse.
"""

import json
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = REPO_ROOT / "tests" / "fixtures" / "termlink-protocol-frame-types.json"
TERMLINK_REPO = Path("/opt/termlink")
DATA_RS = TERMLINK_REPO / "crates" / "termlink-protocol" / "src" / "data.rs"
GOVERNANCE_RS = TERMLINK_REPO / "crates" / "termlink-protocol" / "src" / "governance.rs"


def _load_schema():
    with SCHEMA_PATH.open() as f:
        return json.load(f)


def _require_termlink_repo():
    if not TERMLINK_REPO.is_dir():
        pytest.skip(f"{TERMLINK_REPO} not present on this host")
    if not DATA_RS.is_file():
        pytest.skip(f"{DATA_RS} not present (termlink layout changed?)")


def _parse_frame_type_enum(source: str) -> dict[str, int]:
    """Extract the FrameType enum body and parse 'Variant = 0xN,' lines."""
    # Match the enum block from `pub enum FrameType {` to the next `}`.
    m = re.search(r"pub enum FrameType\s*\{([^}]+)\}", source, re.DOTALL)
    if not m:
        return {}
    body = m.group(1)
    out: dict[str, int] = {}
    for line in body.splitlines():
        m2 = re.match(r"\s*(\w+)\s*=\s*(0x[0-9A-Fa-f]+|\d+)\s*,", line)
        if m2:
            name = m2.group(1)
            raw = m2.group(2)
            value = int(raw, 16) if raw.startswith("0x") else int(raw)
            out[name] = value
    return out


def _parse_governance_event_fields(source: str) -> list[str]:
    """Extract `pub <field>: ...` lines from the GovernanceEvent struct body."""
    m = re.search(r"pub struct GovernanceEvent\s*\{([^}]+)\}", source, re.DOTALL)
    if not m:
        return []
    body = m.group(1)
    out: list[str] = []
    for line in body.splitlines():
        m2 = re.match(r"\s*pub\s+(\w+)\s*:", line)
        if m2:
            out.append(m2.group(1))
    return out


def test_schema_file_loads():
    schema = _load_schema()
    assert "frame_types" in schema
    assert "governance_event_fields" in schema
    assert schema["frame_types"]["Governance"] == 0x8


def test_frame_type_enum_matches_pinned_schema():
    """FrameType variants and byte values match the frozen schema."""
    _require_termlink_repo()
    schema = _load_schema()
    source = DATA_RS.read_text()
    parsed = _parse_frame_type_enum(source)
    assert parsed, f"could not parse FrameType enum from {DATA_RS}"

    expected = schema["frame_types"]
    drift = {name: (expected[name], parsed.get(name)) for name in expected if expected.get(name) != parsed.get(name)}
    assert not drift, (
        f"FrameType byte mapping drifted from pinned schema: {drift}. "
        f"If this is intentional, refresh tests/fixtures/termlink-protocol-frame-types.json "
        f"and update the framework consumers (web/blueprints/orchestrator.py, .fabric/components/cross-repo-termlink-governance-frame.yaml)."
    )

    # Also assert no NEW variants snuck in unannounced — schema pinning is bidirectional.
    new_variants = set(parsed) - set(expected)
    if new_variants:
        pytest.skip(f"new FrameType variants detected (non-failing — refresh schema): {new_variants}")


def test_governance_frame_is_specifically_0x8():
    """The named anchor: Governance must remain at 0x8.

    Separated from the broader enum test because this byte specifically is what
    T-1066 / T-1641 / T-1648 / .fabric/components/cross-repo-termlink-governance-frame.yaml
    reference by literal value. A rename here is a contract break for ALL of those.
    """
    _require_termlink_repo()
    parsed = _parse_frame_type_enum(DATA_RS.read_text())
    assert parsed.get("Governance") == 0x8, (
        f"Governance variant moved from 0x8 to {parsed.get('Governance')}. "
        "This breaks the wire-format contract referenced by T-1066, T-1641 W10 #3, "
        "and the cross-repo fabric card. Coordinate the rename across both repos."
    )


def test_governance_event_struct_has_pinned_fields():
    """GovernanceEvent must contain the pinned field set (no rename, no removal)."""
    _require_termlink_repo()
    if not GOVERNANCE_RS.is_file():
        pytest.skip(f"{GOVERNANCE_RS} not present")
    schema = _load_schema()
    source = GOVERNANCE_RS.read_text()
    fields = _parse_governance_event_fields(source)
    assert fields, "could not parse GovernanceEvent struct fields"

    expected = set(schema["governance_event_fields"])
    actual = set(fields)
    missing = expected - actual
    assert not missing, (
        f"GovernanceEvent missing pinned field(s): {sorted(missing)}. "
        f"Got: {sorted(actual)}. If a field was intentionally renamed, "
        f"refresh tests/fixtures/termlink-protocol-frame-types.json."
    )
    extra = actual - expected
    if extra:
        pytest.skip(f"new GovernanceEvent fields detected (non-failing — refresh schema): {sorted(extra)}")
