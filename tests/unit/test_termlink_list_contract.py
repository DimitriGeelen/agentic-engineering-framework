"""T-1651 — TermLink `list --json` schema contract test.

Three framework consumers read session objects from `termlink list --json`:
- plugins/wezterm/termlink-chrome.lua  (roles, role, tags)
- web/blueprints/orchestrator.py       (id, name, display_name, state, tags)
- agents/audit/orchestrator-mcp-scan.sh (display_name, name, id, tags)

If termlink renames or removes any of those keys, all three break silently.
This contract test pins the keys against a frozen schema so a rename lands
as a test failure, not a runtime ghost.
"""

import json
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = REPO_ROOT / "tests" / "fixtures" / "termlink-list-schema.json"


def _load_schema():
    with SCHEMA_PATH.open() as f:
        return json.load(f)


def _termlink_list():
    """Return parsed `termlink list --json` output. Skip if termlink unavailable."""
    if not shutil.which("termlink"):
        pytest.skip("termlink binary not on PATH")
    try:
        proc = subprocess.run(
            ["termlink", "list", "--json"],
            capture_output=True,
            text=True,
            timeout=8,
        )
    except (subprocess.TimeoutExpired, OSError) as exc:
        pytest.skip(f"termlink unreachable: {exc}")
    if proc.returncode != 0:
        pytest.skip(f"termlink list exited {proc.returncode}: {proc.stderr[:200]}")
    try:
        return json.loads(proc.stdout or "{}")
    except json.JSONDecodeError as exc:
        pytest.fail(f"termlink list returned non-JSON: {exc}")


def test_schema_file_loads():
    schema = _load_schema()
    assert "session_required_keys" in schema
    assert "session_optional_keys" in schema
    assert isinstance(schema["session_required_keys"], list)
    assert len(schema["session_required_keys"]) > 0


def test_top_level_required_keys_present():
    schema = _load_schema()
    data = _termlink_list()
    missing = set(schema["top_level_required"]) - set(data.keys())
    assert not missing, (
        f"Top-level keys missing from termlink list output: {sorted(missing)}. "
        f"Got: {sorted(data.keys())}"
    )


def test_each_session_carries_required_keys():
    """Every session in live output must carry every required key."""
    schema = _load_schema()
    data = _termlink_list()
    sessions = data.get("sessions", []) or []
    if not sessions:
        pytest.skip("no live sessions to validate against")

    required = set(schema["session_required_keys"])
    breaks = []
    for s in sessions:
        missing = required - set(s.keys())
        if missing:
            breaks.append((s.get("display_name") or s.get("id") or "?", sorted(missing)))
    assert not breaks, (
        f"{len(breaks)} session(s) missing required keys; first 3: {breaks[:3]}"
    )


def test_no_unknown_top_level_keys_indicate_breaking_change():
    """If termlink starts returning unknown top-level keys, that's a heads-up
    (warn-only — not a break, but a signal to refresh the schema)."""
    schema = _load_schema()
    data = _termlink_list()
    known = set(schema["top_level_required"])
    extra = set(data.keys()) - known
    if extra:
        pytest.skip(f"new top-level keys (refresh schema): {sorted(extra)}")


def test_tag_format_canonical_prefixes_documented():
    """Schema must list which tag prefixes the orchestrator routes on.
    Source of truth for T-1649 lint and the cross-repo proposal."""
    schema = _load_schema()
    prefixes = schema.get("tag_canonical_prefixes", [])
    assert "task-type:" in prefixes
    assert "task:" in prefixes
    assert "role:" in prefixes
    assert "host=" in prefixes
    assert "project=" in prefixes
