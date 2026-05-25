"""T-2049 — docgen dependency-target resolution.

Pins the contract that the component doc generator resolves dependency targets
(which may be a fabric id like C-007 OR a path) to a human-readable cross-link
plus description, and falls back to raw code for unknown targets. Origin:
T-2047 review feedback — /docs/generated detail pages showed bare `C-007` codes
and non-clickable dependency targets.
"""
import os
import sys

import yaml

DOCGEN_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "agents",
    "docgen",
)
sys.path.insert(0, DOCGEN_DIR)

from generate_component import (  # noqa: E402
    build_card_index,
    _resolve_target,
    _esc_cell,
    generate_doc,
)


def _write_card(path, **fields):
    with open(path, "w") as f:
        yaml.safe_dump(fields, f)


def _make_fabric(tmp_path):
    """Build a minimal fabric with two cards so targets resolve by id and path."""
    comp = tmp_path / ".fabric" / "components"
    comp.mkdir(parents=True)
    _write_card(
        str(comp / "budget-gate.yaml"),
        id="C-007",
        name="budget-gate",
        location="agents/context/budget-gate.sh",
        purpose="Blocks tool execution at critical budget.",
    )
    _write_card(
        str(comp / "checkpoint.yaml"),
        id="C-008",
        name="checkpoint",
        location="agents/context/checkpoint.sh",
        purpose="Post-tool budget monitoring.",
    )
    return str(tmp_path)


def test_resolve_by_fabric_id(tmp_path):
    """A C-NNN target resolves to a /docs/generated/<slug> link + purpose."""
    root = _make_fabric(tmp_path)
    idx = build_card_index(root)
    display, desc = _resolve_target("C-007", idx)
    assert display == "[budget-gate](/docs/generated/budget-gate)"
    assert desc == "Blocks tool execution at critical budget."


def test_resolve_by_path(tmp_path):
    """A path target resolves to the owning card's link + purpose."""
    root = _make_fabric(tmp_path)
    idx = build_card_index(root)
    display, desc = _resolve_target("agents/context/checkpoint.sh", idx)
    assert display == "[checkpoint](/docs/generated/checkpoint)"
    assert desc == "Post-tool budget monitoring."


def test_unknown_target_falls_back_to_raw_code(tmp_path):
    """An unresolved target renders as inline code, no crash, no link."""
    root = _make_fabric(tmp_path)
    idx = build_card_index(root)
    display, desc = _resolve_target("Z-999-does-not-exist", idx)
    assert display == "`Z-999-does-not-exist`"
    assert desc == ""
    assert "/docs/generated/" not in display


def test_pipe_in_cell_is_escaped():
    """Pipes in notes/purposes must be escaped so they don't split table cells."""
    assert _esc_cell("PreToolUse hook on Write|Edit|Bash") == (
        "PreToolUse hook on Write\\|Edit\\|Bash"
    )


def test_generated_doc_renders_resolved_link(tmp_path):
    """End-to-end: a card whose dep is a C-NNN id emits a cross-link, not a bare code."""
    root = _make_fabric(tmp_path)
    comp = tmp_path / ".fabric" / "components"
    _write_card(
        str(comp / "hook-config.yaml"),
        id="C-009",
        name="hook-config",
        location=".claude/settings.json",
        purpose="Hook wiring.",
        depends_on=[
            {"target": "C-007", "type": "triggers", "note": "PreToolUse Write|Edit"},
            {"target": "Q-404", "type": "triggers"},
        ],
    )
    out_dir = tmp_path / "out"
    out_dir.mkdir()
    idx = build_card_index(root)
    generate_doc(str(comp / "hook-config.yaml"), root, str(out_dir), idx)
    md = (out_dir / "hook-config.md").read_text()
    # Resolved id → cross-link with description; note pipe escaped.
    assert "[budget-gate](/docs/generated/budget-gate)" in md
    assert "Write\\|Edit" in md
    # Unknown id → raw code fallback, no phantom link.
    assert "`Q-404`" in md
    # No bare `C-007` token survives (it was resolved away).
    assert "`C-007`" not in md
