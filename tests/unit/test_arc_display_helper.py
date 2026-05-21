"""T-1969: pin the arc_display(arc_id_or_slug) helper.

Behavioural contract:
  - Empty / None / whitespace → ""
  - arc-NNN form input → "arc-NNN · slug"
  - slug form input → "arc-NNN · slug" (same output, normalised)
  - YAML missing `id:` → returns slug alone
  - id == slug (degenerate) → returns single form, no " · "
  - Unresolvable input → returns input verbatim (orphan)

Uses a temp .context/arcs/ tree + monkeypatched _arcs_dir() so the test
is independent of the live arc corpus.
"""
import importlib
from pathlib import Path

import pytest
import yaml


@pytest.fixture
def temp_arcs(tmp_path, monkeypatch):
    """Build a synthetic .context/arcs/ with a canonical, a legacy (no id),
    and a degenerate (id==slug) arc."""
    arcs_dir = tmp_path / "arcs"
    arcs_dir.mkdir()
    (arcs_dir / "value-prioritisation.yaml").write_text(yaml.safe_dump({
        "id": "arc-006",
        "slug": "value-prioritisation",
        "name": "Value prioritisation",
    }))
    (arcs_dir / "legacy-noid.yaml").write_text(yaml.safe_dump({
        "slug": "legacy-noid",  # id field intentionally missing
        "name": "Legacy arc predating dual-id migration",
    }))
    (arcs_dir / "degenerate.yaml").write_text(yaml.safe_dump({
        "id": "degenerate",
        "slug": "degenerate",  # id == slug
        "name": "Edge case",
    }))

    # Reload module to pick up patched _arcs_dir and reset the lru_cache
    from web.blueprints import arcs as arcs_module
    importlib.reload(arcs_module)
    monkeypatch.setattr(arcs_module, "_arcs_dir", lambda: arcs_dir)
    arcs_module.arc_display.cache_clear()
    return arcs_module


def test_empty_input_returns_empty_string(temp_arcs):
    assert temp_arcs.arc_display("") == ""
    assert temp_arcs.arc_display(None) == ""
    assert temp_arcs.arc_display("   ") == ""


def test_arc_nnn_input_returns_dual_form(temp_arcs):
    assert temp_arcs.arc_display("arc-006") == "arc-006 · value-prioritisation"


def test_slug_input_returns_dual_form(temp_arcs):
    assert temp_arcs.arc_display("value-prioritisation") == "arc-006 · value-prioritisation"


def test_yaml_missing_id_returns_slug_alone(temp_arcs):
    # Legacy arc without `id:` field — fall back to slug only, no separator
    assert temp_arcs.arc_display("legacy-noid") == "legacy-noid"


def test_degenerate_id_equals_slug_returns_single_form(temp_arcs):
    # When id and slug are identical, no benefit to duplicating them
    assert temp_arcs.arc_display("degenerate") == "degenerate"


def test_unresolvable_input_returns_verbatim(temp_arcs):
    # Orphan reference — return the input as-is so the badge still shows
    # *something* the human can investigate
    assert temp_arcs.arc_display("nonexistent-slug") == "nonexistent-slug"
    assert temp_arcs.arc_display("arc-999") == "arc-999"


def test_lru_cache_memoizes(temp_arcs):
    # Same input twice → cache should register a hit
    temp_arcs.arc_display.cache_clear()
    temp_arcs.arc_display("arc-006")
    temp_arcs.arc_display("arc-006")
    info = temp_arcs.arc_display.cache_info()
    assert info.hits >= 1
    assert info.misses == 1


def test_whitespace_stripped(temp_arcs):
    assert temp_arcs.arc_display("  arc-006  ") == "arc-006 · value-prioritisation"
