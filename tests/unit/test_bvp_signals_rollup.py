"""T-1939: pin the `_bvp_signals` rollup parity with /bvp scatter.

The `/arcs/<slug>` BVP signals block and the `/bvp` scatter must render
the same arc data — they read from the same fields. Until T-1939, the
signals block had no fallback to constituent rollup; this test fixes that
contract in place.
"""

from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from web.blueprints import arcs as arcs_bp
from web.blueprints import bvp as bvp_bp


def _make_task_file(dir_, task_id, arc_id, scores=None, proposed=None):
    lines = [
        "---",
        f"id: {task_id}",
        f"name: \"{task_id}\"",
        "status: started-work",
        "workflow_type: build",
        "owner: agent",
        "horizon: now",
        f"arc_id: {arc_id}",
    ]
    if scores:
        lines.append("bvp_scores:")
        for k, v in scores.items():
            lines.append(f"  {k}: {v}")
    if proposed:
        lines.append("bvp_scores_proposed:")
        lines.append("  - ts: '2026-05-19T20:00:00Z'")
        lines.append("    scores:")
        for k, v in proposed.items():
            lines.append(f"      {k}: {v}")
    lines.append("---")
    lines.append("body")
    (dir_ / f"{task_id}-test.md").write_text("\n".join(lines) + "\n")


def _setup_tmp(tmp_path):
    """Wire tmp PROJECT_ROOT into both blueprint modules."""
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".context" / "arcs").mkdir(parents=True)
    return tmp_path


def test_bvp_signals_direct_confirmed_takes_precedence(tmp_path, monkeypatch):
    _setup_tmp(tmp_path)
    monkeypatch.setattr(arcs_bp, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(bvp_bp, "PROJECT_ROOT", tmp_path)
    arc = {
        "id": "arc-099",
        "slug": "tarc",
        "bvp_scores": {"D1": 5, "D2": 5, "D3": 5, "D4": 5},
    }
    out = arcs_bp._bvp_signals(arc, "tarc", "arc-099")
    assert out["has_scores"] is True
    assert out["bvp_mode"] == "direct-confirmed"
    # Constituent rollup should not have been used.
    _make_task_file(tmp_path / ".tasks" / "active", "T-91000", "tarc",
                    scores={"D1": 0, "D2": 0, "D3": 0, "D4": 0})
    out2 = arcs_bp._bvp_signals(arc, "tarc", "arc-099")
    # Still direct-confirmed and using arc's own scores (not member's zeros).
    assert out2["bvp_mode"] == "direct-confirmed"
    assert out2["raw"] > 0


def test_bvp_signals_falls_back_to_direct_proposed(tmp_path, monkeypatch):
    _setup_tmp(tmp_path)
    monkeypatch.setattr(arcs_bp, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(bvp_bp, "PROJECT_ROOT", tmp_path)
    arc = {
        "id": "arc-099",
        "slug": "tarc",
        "bvp_scores_proposed": [
            {"ts": "2026-05-19T20:00:00Z",
             "scores": {"D1": 4, "D2": 3, "D3": 3, "D4": 2}}
        ],
    }
    out = arcs_bp._bvp_signals(arc, "tarc", "arc-099")
    assert out["has_scores"] is True
    assert out["bvp_mode"] == "direct-proposed"


def test_bvp_signals_rolls_up_from_confirmed_members(tmp_path, monkeypatch):
    _setup_tmp(tmp_path)
    monkeypatch.setattr(arcs_bp, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(bvp_bp, "PROJECT_ROOT", tmp_path)
    _make_task_file(tmp_path / ".tasks" / "active", "T-91001", "tarc",
                    scores={"D1": 4, "D2": 2})
    _make_task_file(tmp_path / ".tasks" / "active", "T-91002", "tarc",
                    scores={"D1": 2, "D2": 2})
    arc = {"id": "arc-099", "slug": "tarc"}
    out = arcs_bp._bvp_signals(arc, "tarc", "arc-099")
    assert out["has_scores"] is True
    assert out["bvp_mode"] == "derived-confirmed"
    # D1 mean = 3, D2 mean = 2 → raw = 3*9 + 2*7 = 41
    assert out["raw"] == 41


def test_bvp_signals_rolls_up_mixed_degrades_to_proposed(tmp_path, monkeypatch):
    _setup_tmp(tmp_path)
    monkeypatch.setattr(arcs_bp, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(bvp_bp, "PROJECT_ROOT", tmp_path)
    _make_task_file(tmp_path / ".tasks" / "active", "T-91003", "tarc",
                    scores={"D1": 4})  # confirmed
    _make_task_file(tmp_path / ".tasks" / "active", "T-91004", "tarc",
                    proposed={"D1": 2})  # proposed
    arc = {"id": "arc-099", "slug": "tarc"}
    out = arcs_bp._bvp_signals(arc, "tarc", "arc-099")
    assert out["has_scores"] is True
    assert out["bvp_mode"] == "derived-proposed"


def test_bvp_signals_no_signal_anywhere(tmp_path, monkeypatch):
    _setup_tmp(tmp_path)
    monkeypatch.setattr(arcs_bp, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(bvp_bp, "PROJECT_ROOT", tmp_path)
    # No tasks, no proposed scores on arc.
    arc = {"id": "arc-099", "slug": "tarc"}
    out = arcs_bp._bvp_signals(arc, "tarc", "arc-099")
    assert out["has_scores"] is False
    assert out["bvp_mode"] == ""
    assert out["raw"] == 0


def test_bvp_signals_dual_arc_id_form_matches_members(tmp_path, monkeypatch):
    """Member tasks bind via slug OR canonical arc-NNN — same as web /bvp."""
    _setup_tmp(tmp_path)
    monkeypatch.setattr(arcs_bp, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(bvp_bp, "PROJECT_ROOT", tmp_path)
    _make_task_file(tmp_path / ".tasks" / "active", "T-91005", "tarc",
                    scores={"D1": 5})
    _make_task_file(tmp_path / ".tasks" / "active", "T-91006", "arc-099",
                    scores={"D1": 1})
    arc = {"id": "arc-099", "slug": "tarc"}
    out = arcs_bp._bvp_signals(arc, "tarc", "arc-099")
    assert out["has_scores"] is True
    # Both members contribute: mean(D1) = 3
    assert out["bvp_mode"] == "derived-confirmed"
    assert out["per_driver"][0]["score"] == 3
