"""Unit tests for the BVP estimator (T-1922, arc-006).

Coverage:
  - Determinism: same task body → same scores (R3, ship-blocking)
  - M3 v2-delta: skip when confirmed differs <2; append when ≥2
  - Sovereignty: never writes to bvp_scores: (only bvp_scores_proposed:)
  - Frontmatter preservation across the write cycle
  - Per-driver scoring contract: returns int 0-5 with evidence list

Calibration against rubric worked examples is covered by the A3 report
(`docs/reports/T-1922-a3-measurement.md`), not these tests — calibration
is policy not invariant.
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

import pytest

# Make the estimator importable. PROJECT_ROOT is the framework repo root
# (this file lives at $PROJECT_ROOT/tests/unit/test_bvp_estimator.py).
PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "agents" / "termlink" / "bvp-estimator"))
os.environ.setdefault("PROJECT_ROOT", str(PROJECT_ROOT))
os.environ.setdefault("FRAMEWORK_ROOT", str(PROJECT_ROOT))

import estimator  # noqa: E402


# ----------------------------------------------------------------- fixtures

DRIVERS = {"D1": 9, "D2": 7, "D3": 5, "D4": 3}


def _make_task(tmp_path: Path, body: str, fm_extra: dict | None = None) -> Path:
    """Write a synthetic task file and return its path."""
    fm_extra = fm_extra or {}
    fm_lines = [
        "id: T-9999",
        "name: \"Synthetic test task\"",
        "status: started-work",
        "workflow_type: build",
        "owner: agent",
        "horizon: now",
    ]
    tags = fm_extra.get("tags") or []
    if tags:
        fm_lines.append(f"tags: [{', '.join(tags)}]")
    for k, v in fm_extra.items():
        if k == "tags":
            continue
        fm_lines.append(f"{k}: {v}")
    path = tmp_path / "T-9999-synthetic.md"
    path.write_text("---\n" + "\n".join(fm_lines) + "\n---\n\n" + body + "\n")
    return path


# ----------------------------------------------------------- per-driver shape

def test_each_driver_returns_int_0_to_5():
    fm = {"workflow_type": "build", "tags": []}
    body = ""
    for handler in (
        estimator.score_d1_antifragility,
        estimator.score_d2_reliability,
        estimator.score_d3_usability,
        estimator.score_d4_portability,
    ):
        score, ev = handler(fm, body, [])
        assert isinstance(score, int)
        assert 0 <= score <= 5
        assert isinstance(ev, list)
        assert any(e.startswith("→") for e in ev), "evidence should include a → arrow line"


def test_empty_body_scores_zero_on_all_drivers():
    fm = {"workflow_type": "build", "tags": []}
    for handler in (
        estimator.score_d1_antifragility,
        estimator.score_d2_reliability,
        estimator.score_d3_usability,
        estimator.score_d4_portability,
    ):
        score, _ = handler(fm, "", [])
        assert score == 0


# -------------------------------------------------- d1 signal escalation

def test_d1_structural_gate_keyword_scores_4():
    """A body mentioning a PreToolUse hook should escalate D1 to 4."""
    fm = {"workflow_type": "build", "tags": []}
    body = "Added a PreToolUse hook that refuses --status work-completed for unscored tasks."
    score, _ = estimator.score_d1_antifragility(fm, body, [])
    assert score == 4


def test_d1_novel_mechanism_tag_plus_class_body_scores_5():
    fm = {"workflow_type": "build", "tags": ["novel-mechanism"]}
    body = "Introduces a new sovereignty boundary at policy-edit time."
    score, ev = estimator.score_d1_antifragility(fm, body, ["novel-mechanism"])
    assert score == 5


def test_d1_bug_with_learning_ref_scores_2():
    fm = {"workflow_type": "build", "tags": ["fix"]}
    body = "Fix the bug in update-task.sh (L-291)."
    score, _ = estimator.score_d1_antifragility(fm, body, ["fix"])
    assert score == 2


# -------------------------------------------------- d2 silent-failure class

def test_d2_silent_class_keyword_scores_5():
    fm = {"workflow_type": "build", "tags": []}
    body = "Removes the silent-failure class where SIGPIPE caused exit 141 with no message."
    score, _ = estimator.score_d2_reliability(fm, body, [])
    assert score == 5


def test_d2_fw_doctor_keyword_scores_4():
    fm = {"workflow_type": "build", "tags": []}
    body = "Added an fw doctor check that surfaces cron-registry drift."
    score, _ = estimator.score_d2_reliability(fm, body, [])
    assert score == 4


# ----------------------------------------------------- determinism contract

def test_same_input_same_output(tmp_path):
    """R3 ship-blocking AC: deterministic by construction."""
    body = "Added a PreToolUse hook with audit FAIL on drift. Cross-machine semantics."
    path = _make_task(tmp_path, body)
    r1 = estimator.estimate_task(path, DRIVERS)
    r2 = estimator.estimate_task(path, DRIVERS)
    r3 = estimator.estimate_task(path, DRIVERS)
    assert r1["scores"] == r2["scores"] == r3["scores"]


def test_determinism_holds_with_random_body(tmp_path):
    """Throw a varied body at the engine — output must still be repeatable."""
    body = """## Context

This is a build task that adds a fw doctor check, a regression test in
tests/playwright/, and removes a hard-coded port. The PreToolUse hook
refuses operations when the rubric drifts. Cross-machine semantics
preserved. L-403 reference. Recommendation block format.
"""
    path = _make_task(tmp_path, body)
    runs = [estimator.estimate_task(path, DRIVERS) for _ in range(10)]
    base = runs[0]["scores"]
    for r in runs[1:]:
        assert r["scores"] == base


# -------------------------------------------------- m3 v2-delta semantics

def test_v2_delta_skip_when_confirmed_within_1():
    proposed = {"D1": 4, "D2": 3, "D3": 0, "D4": 0}
    confirmed = {"D1": 4, "D2": 3, "D3": 0, "D4": 1}
    assert estimator._v2_delta_should_skip(proposed, confirmed) is True


def test_v2_delta_no_skip_when_any_driver_delta_2():
    proposed = {"D1": 4, "D2": 3, "D3": 0, "D4": 0}
    confirmed = {"D1": 4, "D2": 1, "D3": 0, "D4": 0}  # D2 differs by 2
    assert estimator._v2_delta_should_skip(proposed, confirmed) is False


def test_v2_delta_no_skip_when_no_confirmed():
    proposed = {"D1": 4, "D2": 3, "D3": 0, "D4": 0}
    assert estimator._v2_delta_should_skip(proposed, {}) is False
    assert estimator._v2_delta_should_skip(proposed, None) is False


# --------------------------------------------------- write contract

def test_write_creates_bvp_scores_proposed(tmp_path):
    """Writing must populate frontmatter's bvp_scores_proposed: as a list of dicts."""
    body = "Added a PreToolUse hook."
    path = _make_task(tmp_path, body)
    result = estimator.estimate_task(path, DRIVERS)
    wrote, reason = estimator.write_proposed(
        path, result["scores"], result["evidence"],
        result["rubric_sha"], dry_run=False
    )
    assert wrote is True, reason
    fm, _ = estimator.parse_task(path)
    assert isinstance(fm.get("bvp_scores_proposed"), list)
    latest = fm["bvp_scores_proposed"][-1]
    assert latest["estimator"] == estimator.ESTIMATOR_ID
    assert set(latest["scores"].keys()) == {"D1", "D2", "D3", "D4"}
    assert "rubric_sha" in latest


def test_write_never_touches_confirmed_scores(tmp_path):
    """Sovereignty: estimator must NOT mutate bvp_scores: even when present."""
    body = "Added a PreToolUse hook."
    path = _make_task(tmp_path, body)
    # Pre-set confirmed scores
    original = path.read_text()
    modified = original.replace(
        "---\n\n",
        "bvp_scores:\n  D1: 1\n  D2: 1\n  D3: 1\n  D4: 1\n---\n\n",
        1,
    )
    path.write_text(modified)

    result = estimator.estimate_task(path, DRIVERS)
    estimator.write_proposed(
        path, result["scores"], result["evidence"],
        result["rubric_sha"], dry_run=False
    )

    fm, _ = estimator.parse_task(path)
    # Confirmed values untouched
    assert fm["bvp_scores"] == {"D1": 1, "D2": 1, "D3": 1, "D4": 1}


def test_write_skips_when_v2_delta_below_threshold(tmp_path):
    """If confirmed already exists and proposal is within ±1, do not write."""
    body = "Added a PreToolUse hook."
    path = _make_task(tmp_path, body)
    # First estimate writes proposed (no confirmed yet)
    result1 = estimator.estimate_task(path, DRIVERS)

    # Pre-set confirmed to match the proposal exactly
    original = path.read_text()
    confirmed_block = "bvp_scores:\n" + "".join(
        f"  {k}: {v}\n" for k, v in result1["scores"].items()
    )
    modified = original.replace("---\n\n", confirmed_block + "---\n\n", 1)
    path.write_text(modified)

    # Re-run: should skip
    result2 = estimator.estimate_task(path, DRIVERS)
    wrote, reason = estimator.write_proposed(
        path, result2["scores"], result2["evidence"],
        result2["rubric_sha"], dry_run=False
    )
    assert wrote is False
    assert reason == "v2-delta-skip"


# --------------------------------------------------- robustness

def test_missing_frontmatter_handled(tmp_path):
    path = tmp_path / "T-9999-no-fm.md"
    path.write_text("Just a body, no frontmatter at all.\n")
    fm, body = estimator.parse_task(path)
    assert fm == {}
    assert body.startswith("Just a body")


def test_estimate_returns_required_fields(tmp_path):
    path = _make_task(tmp_path, "Simple body.")
    result = estimator.estimate_task(path, DRIVERS)
    for field in ("scores", "evidence", "version", "rubric_sha", "latency_s"):
        assert field in result, f"missing {field}"
    assert result["version"] == "bvp-estimator-v1-heuristic"
    assert result["latency_s"] >= 0


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))
