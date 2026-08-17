"""Unit tests for the T-2189 inception scoring exception in the BVP estimator.

Coverage:
  - `_score_inception_voi`: voi=0.9 → 4, voi=0.1 → 0, missing → 2,
    malformed → 2, out-of-range clamped to [0,5].
  - `score_blast_radius`: inception with `target_blast_radius` substitutes
    the value (clamped 0..9); inception without falls back to component-
    count path; build-task path is unchanged.
  - `estimate_task`: inceptions route every requested driver through
    `_score_inception_voi` (same score for all); build/refactor/test paths
    are unchanged (regression guard).
  - Rank parity: inception(voi=0.9) outscores inception(voi=0.1) on the
    same driver set.

T-2189 / T-2186 slice 3. See 050-Inceptions.md §Scoring Exception and
policy/value-drivers.yaml §inception_scoring_exception.
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

# Importable estimator path (mirrors test_bvp_estimator.py)
PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "agents" / "termlink" / "bvp-estimator"))
os.environ.setdefault("PROJECT_ROOT", str(PROJECT_ROOT))
os.environ.setdefault("FRAMEWORK_ROOT", str(PROJECT_ROOT))

import estimator  # noqa: E402


# ── _score_inception_voi ──────────────────────────────────────────────────


def test_voi_high_scores_high():
    sc, ev = estimator._score_inception_voi(
        {"workflow_type": "inception", "voi_score": 0.9}, "", []
    )
    assert sc == 4  # round(0.9*5)
    assert "voi:0.90" in ev[0]


def test_voi_low_scores_low():
    sc, ev = estimator._score_inception_voi(
        {"workflow_type": "inception", "voi_score": 0.1}, "", []
    )
    assert sc == 0
    assert "voi:0.10" in ev[0]


def test_voi_missing_returns_neutral_with_grandfathered_marker():
    sc, ev = estimator._score_inception_voi(
        {"workflow_type": "inception"}, "", []
    )
    assert sc == 2
    assert "grandfathered" in ev[0]


def test_voi_malformed_returns_neutral_with_marker():
    sc, ev = estimator._score_inception_voi(
        {"workflow_type": "inception", "voi_score": "not-a-number"}, "", []
    )
    assert sc == 2
    assert "malformed" in ev[0]


def test_voi_out_of_range_is_clamped():
    sc_hi, _ = estimator._score_inception_voi(
        {"workflow_type": "inception", "voi_score": 1.5}, "", []
    )
    sc_lo, _ = estimator._score_inception_voi(
        {"workflow_type": "inception", "voi_score": -0.3}, "", []
    )
    assert sc_hi == 5
    assert sc_lo == 0


# ── score_blast_radius substitution ───────────────────────────────────────


def test_inception_target_blast_radius_substitutes():
    sc, ev = estimator.score_blast_radius(
        {"workflow_type": "inception", "target_blast_radius": 7, "components": []},
        "",
        [],
    )
    assert sc == 7
    assert "target_blast_radius" in ev[0]


def test_inception_target_blast_radius_clamped():
    sc, _ = estimator.score_blast_radius(
        {"workflow_type": "inception", "target_blast_radius": 99, "components": []},
        "",
        [],
    )
    assert sc == 9
    sc_neg, _ = estimator.score_blast_radius(
        {"workflow_type": "inception", "target_blast_radius": -5, "components": []},
        "",
        [],
    )
    assert sc_neg == 0


def test_inception_missing_tbr_falls_back_to_components_count():
    """T-3068: was `assert sc == 0`.

    The fallback still happens — an inception with no `target_blast_radius` still
    drops through to the component count. What changed is what that count reports
    when there is nothing to count: an explicit unknown instead of the cheapest
    value on the heaviest cost term. T-2189 identified this shape for inceptions and
    fixed it by adding `target_blast_radius`; the same sentence was true of every
    task with empty components, which is what T-3068 closes.
    """
    sc, ev = estimator.score_blast_radius(
        {"workflow_type": "inception", "components": []}, "", []
    )
    assert sc is None
    assert "no-components" in ev[0]


def test_inception_malformed_tbr_falls_back_to_components():
    sc, ev = estimator.score_blast_radius(
        {
            "workflow_type": "inception",
            "target_blast_radius": "not-a-number",
            "components": ["a", "b", "c"],
        },
        "",
        [],
    )
    # falls through to components-count path (3 components → 3)
    assert sc == 3
    assert "components" in ev[0]


def test_build_blast_radius_unchanged_regression():
    """Build-task scoring path must be unchanged pre/post T-2189.

    T-3068 changed exactly one row of this table: empty components now reports
    unknown rather than 0. The rest of the ladder is untouched, which is what this
    test is for — the T-3068 change had to be surgical, not a rewrite of the scale.
    """
    # Semantics: 1/3/5/7/9 ladder by component count; None when there is no count.
    cases = [
        ({"workflow_type": "build", "components": []}, None),
        ({"workflow_type": "build", "components": ["a"]}, 1),
        ({"workflow_type": "build", "components": ["a", "b", "c"]}, 3),
        ({"workflow_type": "build", "components": ["a"] * 5}, 5),
        ({"workflow_type": "build", "components": ["a"] * 8}, 7),
        ({"workflow_type": "build", "components": ["a"] * 12}, 9),
    ]
    for fm, expected in cases:
        sc, _ = estimator.score_blast_radius(fm, "", [])
        assert sc == expected, f"{fm} → {sc}, expected {expected}"


# ── estimate_task routing ─────────────────────────────────────────────────


def _make_task_file(fm_yaml: str, body: str = "") -> Path:
    """Write a temp task file and return its path."""
    fd = tempfile.NamedTemporaryFile(
        mode="w", suffix=".md", delete=False, encoding="utf-8"
    )
    fd.write("---\n")
    fd.write(fm_yaml)
    fd.write("\n---\n")
    fd.write(body)
    fd.close()
    return Path(fd.name)


def test_estimate_task_inception_routes_all_drivers_through_voi():
    task = _make_task_file(
        "id: T-9999\nworkflow_type: inception\nvoi_score: 0.8\ntags: []\ncomponents: []\n"
    )
    try:
        result = estimator.estimate_task(
            task, {"D1": 9, "D2": 7, "D3": 5, "D4": 3, "F-CUSTOM": 4}
        )
    finally:
        task.unlink()

    # All five drivers got the same voi-derived score (round(0.8*5) = 4)
    assert result["scores"]["D1"] == 4
    assert result["scores"]["D2"] == 4
    assert result["scores"]["D3"] == 4
    assert result["scores"]["D4"] == 4
    assert result["scores"]["F-CUSTOM"] == 4
    # Evidence indicates voi-derivation, not per-driver mechanism rubrics
    for driver_id in ("D1", "D2", "D3", "D4", "F-CUSTOM"):
        assert any("voi:" in e for e in result["evidence"][driver_id])


def test_estimate_task_build_unchanged_regression():
    """Build tasks must NOT route through the inception exception."""
    task = _make_task_file(
        "id: T-9999\nworkflow_type: build\ntags: []\ncomponents: ['a']\n",
        body="some body text\n## Acceptance Criteria\n- [ ] AC1\n",
    )
    try:
        result = estimator.estimate_task(task, {"D1": 9})
    finally:
        task.unlink()
    # D1 went through the real handler; evidence should NOT mention voi
    d1_evidence = result["evidence"]["D1"]
    assert not any("voi:" in e for e in d1_evidence)


def test_inception_rank_parity_high_voi_outscores_low_voi():
    """Two inceptions same shape; high-voi wins by mechanism alone."""
    drivers = {"D1": 9, "D2": 7}
    hi_task = _make_task_file(
        "id: T-A\nworkflow_type: inception\nvoi_score: 0.9\ntags: []\ncomponents: []\n"
    )
    lo_task = _make_task_file(
        "id: T-B\nworkflow_type: inception\nvoi_score: 0.1\ntags: []\ncomponents: []\n"
    )
    try:
        hi = estimator.estimate_task(hi_task, drivers)
        lo = estimator.estimate_task(lo_task, drivers)
    finally:
        hi_task.unlink()
        lo_task.unlink()

    hi_total = sum(hi["scores"].values())
    lo_total = sum(lo["scores"].values())
    assert hi_total > lo_total
    assert hi_total == 8   # 4 + 4
    assert lo_total == 0   # 0 + 0
