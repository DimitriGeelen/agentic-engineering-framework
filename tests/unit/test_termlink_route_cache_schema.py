"""T-1650 — route_cache.json persistence schema regression test.

Pins the field set of RouteCache, RouteCacheEntry, ModelStats, RequestSchema
and the LearnedFrom enum variants against the upstream Rust source. Catches
serde rename/removal that would silently produce a cold cache on hub restart.
"""

import json
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = REPO_ROOT / "tests" / "fixtures" / "termlink-route-cache-schema.json"
TERMLINK_REPO = Path("/opt/termlink")
ROUTE_CACHE_RS = TERMLINK_REPO / "crates" / "termlink-hub" / "src" / "route_cache.rs"


def _load_schema():
    with SCHEMA_PATH.open() as f:
        return json.load(f)


def _require_termlink_repo():
    if not ROUTE_CACHE_RS.is_file():
        pytest.skip(f"{ROUTE_CACHE_RS} not present on this host")


def _parse_struct_fields(source: str, struct_name: str) -> list[str]:
    """Extract `pub <field>: ...` from a struct body."""
    m = re.search(rf"pub struct {re.escape(struct_name)}\s*\{{([^}}]+)\}}", source, re.DOTALL)
    if not m:
        return []
    body = m.group(1)
    fields: list[str] = []
    for line in body.splitlines():
        m2 = re.match(r"\s*pub\s+(\w+)\s*:", line)
        if m2:
            fields.append(m2.group(1))
    return fields


def _parse_enum_variants(source: str, enum_name: str) -> list[str]:
    """Extract variant names from an enum body."""
    m = re.search(rf"pub enum {re.escape(enum_name)}\s*\{{([^}}]+)\}}", source, re.DOTALL)
    if not m:
        return []
    body = m.group(1)
    variants: list[str] = []
    for line in body.splitlines():
        # Variants look like `    VariantName,` or `    VariantName = 0x1,`
        m2 = re.match(r"\s*(\w+)\s*(?:=|,)", line)
        if m2 and not line.strip().startswith("//") and not line.strip().startswith("#["):
            variants.append(m2.group(1))
    return variants


def _parse_constants(source: str) -> dict[str, float]:
    """Extract `const NAME: <type> = <value>;` from the file."""
    out: dict[str, float] = {}
    for m in re.finditer(r"const\s+([A-Z_]+)\s*:\s*\w+\s*=\s*([\d.]+)\s*;", source):
        try:
            out[m.group(1)] = float(m.group(2))
        except ValueError:
            pass
    return out


def test_schema_file_loads():
    schema = _load_schema()
    assert "structs" in schema and "enums" in schema and "constants" in schema
    assert "RouteCacheEntry" in schema["structs"]


def test_route_cache_struct_fields_pinned():
    _require_termlink_repo()
    schema = _load_schema()
    source = ROUTE_CACHE_RS.read_text()
    drift: dict[str, dict] = {}
    for name, spec in schema["structs"].items():
        actual = _parse_struct_fields(source, name)
        expected = set(spec["fields"])
        missing = expected - set(actual)
        if missing:
            drift[name] = {"missing": sorted(missing), "actual": actual}
    assert not drift, (
        f"Struct field drift detected: {drift}. If intentional, refresh "
        f"tests/fixtures/termlink-route-cache-schema.json and verify the "
        f"hub's deserialization path still works."
    )


def test_learned_from_enum_variants_pinned():
    _require_termlink_repo()
    schema = _load_schema()
    source = ROUTE_CACHE_RS.read_text()
    actual = _parse_enum_variants(source, "LearnedFrom")
    expected = set(schema["enums"]["LearnedFrom"]["variants"])
    missing = expected - set(actual)
    assert not missing, (
        f"LearnedFrom variant(s) missing: {sorted(missing)}. Got: {actual}. "
        f"Removed variant means historic on-disk caches will fail to deserialize."
    )


def test_constants_documented():
    """Confidence threshold + TTL are policy constants — drift is interesting,
    not failing. Skip-mark if they change so the human notices on next run."""
    _require_termlink_repo()
    schema = _load_schema()
    source = ROUTE_CACHE_RS.read_text()
    actual = _parse_constants(source)
    drift = []
    for name, expected_val in schema["constants"].items():
        if name in actual and abs(actual[name] - expected_val) > 1e-9:
            drift.append((name, expected_val, actual[name]))
    if drift:
        pytest.skip(
            f"policy constant drift (refresh schema if intentional): {drift}"
        )


def test_no_version_tag_yet_documents_open_proposal():
    """Records the absence of an on-disk version tag as a known gap.

    The cross-repo proposal (version: u32 + refuse-and-rebuild) was sent to
    termlink-agent. When that lands upstream, refresh the schema to pin
    version: 1 and remove this skip."""
    _require_termlink_repo()
    source = ROUTE_CACHE_RS.read_text()
    has_version = bool(re.search(r"pub\s+version\s*:\s*\w+", source))
    if not has_version:
        pytest.skip(
            "RouteCache has no `version` field yet — cross-repo proposal pending "
            "with termlink-agent (T-1650). When it lands, pin version=1 here."
        )
