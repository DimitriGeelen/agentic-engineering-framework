"""T-1941: pin `bvp_mode` field in /bvp scatter arc payload.

`_collect_arc_points` previously computed `bvp_mode` locally (direct-confirmed
/direct-proposed/derived-confirmed/derived-proposed) but didn't emit it in
the returned payload — the scatter view collapsed all four into a binary
`proposed: bool` and lost the rollup signal. This test pins the contract:
each arc point dict carries `bvp_mode` with the correct 4-tier slug.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))
os.environ.setdefault("PROJECT_ROOT", str(PROJECT_ROOT))

from web.blueprints import bvp as bvp_bp


def _make_arc_yaml(dir_, arc_id, slug, **fields):
    """Arc YAMLs are plain YAML (no Markdown frontmatter markers)."""
    lines = [f"id: {arc_id}", f"slug: {slug}", "status: draft"]
    for k, v in fields.items():
        if isinstance(v, dict):
            lines.append(f"{k}:")
            for kk, vv in v.items():
                lines.append(f"  {kk}: {vv}")
        elif isinstance(v, list):
            lines.append(f"{k}:")
            for entry in v:
                first = True
                for kk, vv in entry.items():
                    prefix = "  - " if first else "    "
                    first = False
                    if isinstance(vv, dict):
                        lines.append(f"{prefix}{kk}:")
                        for vk, vvv in vv.items():
                            lines.append(f"      {vk}: {vvv}")
                    else:
                        lines.append(f"{prefix}{kk}: {vv}")
        else:
            lines.append(f"{k}: {v}")
    (dir_ / f"{slug}.yaml").write_text("\n".join(lines) + "\n")


def _make_task(dir_, task_id, arc_id, scores=None, proposed=None):
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
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".context" / "arcs").mkdir(parents=True)
    return tmp_path


_WEIGHTS = {"D1": 9, "D2": 7, "D3": 5, "D4": 3}


def test_arc_point_carries_bvp_mode_direct_confirmed(tmp_path, monkeypatch):
    _setup_tmp(tmp_path)
    monkeypatch.setattr(bvp_bp, "PROJECT_ROOT", tmp_path)
    _make_arc_yaml(
        tmp_path / ".context" / "arcs",
        arc_id="arc-099",
        slug="tarc",
        bvp_scores={"D1": 5, "D2": 4, "D3": 3, "D4": 2},
    )
    pts = bvp_bp._collect_arc_points(_WEIGHTS)
    assert len(pts) == 1
    assert "bvp_mode" in pts[0], "arc payload must carry bvp_mode key"
    assert pts[0]["bvp_mode"] == "direct-confirmed"
    assert pts[0]["proposed"] is False


def test_arc_point_carries_bvp_mode_direct_proposed(tmp_path, monkeypatch):
    _setup_tmp(tmp_path)
    monkeypatch.setattr(bvp_bp, "PROJECT_ROOT", tmp_path)
    _make_arc_yaml(
        tmp_path / ".context" / "arcs",
        arc_id="arc-099",
        slug="tarc",
        bvp_scores_proposed=[
            {"ts": "2026-05-19T20:00:00Z",
             "scores": {"D1": 4, "D2": 3, "D3": 3, "D4": 2}}
        ],
    )
    pts = bvp_bp._collect_arc_points(_WEIGHTS)
    assert len(pts) == 1
    assert pts[0]["bvp_mode"] == "direct-proposed"
    assert pts[0]["proposed"] is True


def test_arc_point_carries_bvp_mode_derived_confirmed(tmp_path, monkeypatch):
    _setup_tmp(tmp_path)
    monkeypatch.setattr(bvp_bp, "PROJECT_ROOT", tmp_path)
    _make_arc_yaml(
        tmp_path / ".context" / "arcs",
        arc_id="arc-099",
        slug="tarc",
    )
    _make_task(tmp_path / ".tasks" / "active", "T-95001", "tarc",
               scores={"D1": 4, "D2": 2})
    _make_task(tmp_path / ".tasks" / "active", "T-95002", "tarc",
               scores={"D1": 2, "D2": 2})
    pts = bvp_bp._collect_arc_points(_WEIGHTS)
    assert len(pts) == 1
    assert pts[0]["bvp_mode"] == "derived-confirmed"
    assert pts[0]["proposed"] is False


def test_arc_point_carries_bvp_mode_derived_proposed(tmp_path, monkeypatch):
    _setup_tmp(tmp_path)
    monkeypatch.setattr(bvp_bp, "PROJECT_ROOT", tmp_path)
    _make_arc_yaml(
        tmp_path / ".context" / "arcs",
        arc_id="arc-099",
        slug="tarc",
    )
    _make_task(tmp_path / ".tasks" / "active", "T-95003", "tarc",
               scores={"D1": 4})  # confirmed
    _make_task(tmp_path / ".tasks" / "active", "T-95004", "tarc",
               proposed={"D1": 2})  # proposed
    pts = bvp_bp._collect_arc_points(_WEIGHTS)
    assert len(pts) == 1
    assert pts[0]["bvp_mode"] == "derived-proposed"
    assert pts[0]["proposed"] is True


def test_arc_point_omits_no_score_arcs(tmp_path, monkeypatch):
    """Arcs with no direct scores AND no member task scores must not appear
    in the payload — the contract is `bvp_mode` is set whenever a point
    appears, never empty in practice."""
    _setup_tmp(tmp_path)
    monkeypatch.setattr(bvp_bp, "PROJECT_ROOT", tmp_path)
    _make_arc_yaml(
        tmp_path / ".context" / "arcs",
        arc_id="arc-099",
        slug="tarc",
    )
    pts = bvp_bp._collect_arc_points(_WEIGHTS)
    assert pts == []


def test_arc_point_dual_arc_id_form_for_rollup(tmp_path, monkeypatch):
    """T-1849 — members bind via slug OR arc-NNN canonical form."""
    _setup_tmp(tmp_path)
    monkeypatch.setattr(bvp_bp, "PROJECT_ROOT", tmp_path)
    _make_arc_yaml(
        tmp_path / ".context" / "arcs",
        arc_id="arc-099",
        slug="tarc",
    )
    _make_task(tmp_path / ".tasks" / "active", "T-95005", "tarc",
               scores={"D1": 5})
    _make_task(tmp_path / ".tasks" / "active", "T-95006", "arc-099",
               scores={"D1": 1})
    pts = bvp_bp._collect_arc_points(_WEIGHTS)
    assert len(pts) == 1
    assert pts[0]["bvp_mode"] == "derived-confirmed"
    # Both members contributed → mean(D1)=3
    assert pts[0]["scores"]["D1"] == 3
