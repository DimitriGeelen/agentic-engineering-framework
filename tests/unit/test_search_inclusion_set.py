"""T-3024 (T-3022 slice E′): the semantic index inclusion set is a content-class rule.

These tests exist because the previous inclusion set was a list of seven directories
that accreted one at a time, and was wrong in both directions without anything ever
reporting it: 73 authored files unreachable (all of policy/, every ADR), 1,710
handovers indexed in full. A list cannot be wrong — it is whatever it is. A rule can,
which is the point of turning it into one.

The assertions below are deliberately about *class membership*, not file counts, so
they keep meaning as the corpus grows.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web.search_utils import (  # noqa: E402
    AUTHORED_DIRS,
    EXCLUDED_DIRS,
    HANDOVER_DIR,
    collect_files,
)
from web.shared import PROJECT_ROOT  # noqa: E402


def _collected() -> list[str]:
    return [str(p.relative_to(PROJECT_ROOT)) for p in collect_files()]


@pytest.mark.parametrize(
    "prefix",
    ["policy/", "docs/adr/", "docs/architecture/", "docs/design/", "docs/specs/"],
)
def test_authored_content_is_reachable(prefix: str) -> None:
    """Authored-and-durable content spike 8 found unreachable is now indexed.

    Skips rather than fails when a directory does not exist in this checkout — the
    rule is about class, and an absent directory has no class to get wrong.
    """
    if not (PROJECT_ROOT / prefix).exists():
        pytest.skip(f"{prefix} not present in this checkout")
    assert any(f.startswith(prefix) for f in _collected()), (
        f"{prefix} is authored-and-durable but no file from it reached the index"
    )


def test_generated_content_stays_excluded() -> None:
    """docs/generated/ must not leak in.

    This is the guard against fixing the omission by bulk-adding docs/, which would
    repeat the original accretion in the name of correcting it.
    """
    assert not any(f.startswith("docs/generated/") for f in _collected())


def test_keystone_documents_agents_are_told_to_read_are_findable() -> None:
    """The two documents CLAUDE.md directs agents to read must be in the index.

    Named individually rather than by directory: these are the concrete instances
    that made the omission worth fixing, so they are worth failing on by name.
    """
    collected = set(_collected())
    for keystone in (
        "policy/standards/aef-bpmn-mapping-v1-partI.md",
        "policy/prompts/bvp-driver-session.md",
    ):
        if not (PROJECT_ROOT / keystone).exists():
            continue
        assert keystone in collected, f"{keystone} is unreachable by semantic search"


def test_handover_switch_is_explicit_and_defaults_to_on(monkeypatch) -> None:
    """Handovers are a named switch, not an implicit consequence of a listed directory.

    Default is ON so this task changes no behaviour; flipping it is an operator
    decision (T-3024 Human AC), and it must be reversible in both directions.
    """
    handover_prefix = "/".join(HANDOVER_DIR) + "/"

    monkeypatch.setenv("FW_INDEX_HANDOVERS", "1")
    assert any(f.startswith(handover_prefix) for f in _collected())

    monkeypatch.setenv("FW_INDEX_HANDOVERS", "0")
    assert not any(f.startswith(handover_prefix) for f in _collected())

    # Reversible: back on, and the corpus returns rather than staying dropped.
    monkeypatch.setenv("FW_INDEX_HANDOVERS", "1")
    assert any(f.startswith(handover_prefix) for f in _collected())


def test_excluding_handovers_does_not_empty_the_index(monkeypatch) -> None:
    """The rest of the corpus survives the switch.

    Cheap guard against an exclusion implemented as a filter that matches too much —
    the failure mode would be a silently tiny index, which reads as "search is fast".
    """
    monkeypatch.setenv("FW_INDEX_HANDOVERS", "0")
    remaining = _collected()
    assert len(remaining) > 1000, f"index collapsed to {len(remaining)} files"


def test_classes_are_disjoint() -> None:
    """No directory may be declared both authored and excluded."""
    authored = {"/".join(p) for p in AUTHORED_DIRS}
    excluded = {"/".join(p) for p in EXCLUDED_DIRS}
    assert not (authored & excluded), f"declared in both classes: {authored & excluded}"
