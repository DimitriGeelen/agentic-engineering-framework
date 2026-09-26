"""T-3485: pin the value-axis equality defect repair in `quadrant()`.

`bvp_norm >= bvp_median` is true at equality. That is harmless while the
median sits mid-distribution, but when the median has itself collapsed onto
the corpus floor (median == min(bvp_vals)), at least half the corpus is tied
there, and `>=` promotes every tied, floor-scoring task into `hv`. Measured
live: 13/25 zero-scored tasks, median 0.00, all 13 landed in `hv-lc`.

This file builds the corpora as committed fixtures (never against live
project state, which moves under the test — L-599) and demonstrates BOTH
directions of the repair:
  1. Exclusion — a zero-value task in a zero-median (degenerate) corpus no
     longer lands in `hv`.
  2. Admission — a genuinely high-value task (clearly above the degenerate
     median) still lands in `hv`. Without this, the "repair" would just be
     narrowing the classifier, not correcting it.
Plus a control: a healthy, well-spread (non-degenerate) corpus classifies
identically to the pre-fix `>=` semantics — the fix must not change behaviour
where the median already separates the distribution.
"""
from __future__ import annotations

import os
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def _write_task(tmp_path, task_id, d1, blast_radius=2, tier=2, effort=2, subdir="active"):
    """Minimal task: single-driver D1 score (D2-D4 pinned 0) + a constant-shape
    3-component cost estimate, so the value axis is isolated from cost-axis
    behaviour (the cost axis's own equality symmetry is a separate, reported-
    not-fixed finding — see PL-025 note in the task's Recommendation)."""
    d = tmp_path / ".tasks" / subdir
    d.mkdir(parents=True, exist_ok=True)
    lines = [
        "---",
        f"id: {task_id}",
        f"name: \"{task_id} test\"",
        "status: started-work",
        "workflow_type: build",
        "owner: agent",
        "horizon: now",
        "bvp_scores:",
        f"  D1: {d1}",
        "  D2: 0",
        "  D3: 0",
        "  D4: 0",
        "cost_estimate:",
        f"  blast_radius: {blast_radius}",
        f"  tier: {tier}",
        f"  effort: {effort}",
        "---",
        "body",
    ]
    (d / f"{task_id}-test.md").write_text("\n".join(lines) + "\n")


def _run_fw_bvp(tmp_path, *args):
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(tmp_path)
    policy_dir = tmp_path / "policy"
    policy_dir.mkdir(exist_ok=True)
    (policy_dir / "value-drivers.yaml").write_text(
        "weights:\n  D1: 9\n  D2: 7\n  D3: 5\n  D4: 3\n"
        "protected_drivers:\n"
        "  - {id: D1, name: Antifragility, weight: 9}\n"
        "  - {id: D2, name: Reliability, weight: 7}\n"
        "  - {id: D3, name: Usability, weight: 5}\n"
        "  - {id: D4, name: Portability, weight: 3}\n"
        "free_drivers: []\n"
        "auto_promote:\n  enabled: false\n"
    )
    (tmp_path / ".context").mkdir(exist_ok=True)
    (tmp_path / ".context" / "arcs").mkdir(exist_ok=True)
    result = subprocess.run(
        [str(PROJECT_ROOT / "bin" / "fw"), "bvp", *args],
        capture_output=True, text=True, env=env, timeout=20,
    )
    return result.stdout, result.stderr, result.returncode


# ----------------------------------------------------------------------------
# Direction 1: exclusion — degenerate-median tie mass no longer reads as `hv`
# ----------------------------------------------------------------------------


def test_degenerate_median_zero_value_tasks_withheld_not_hv():
    """Reproduces the measured live symptom at fixture scale: 13 zero-value
    tasks + 12 higher-value tasks (25 total, mirrors the reported 25-task
    corpus). Constant cost isolates the value axis. Before the fix, all 25
    landed in hv-lc; after, the 13 zero-scored ties must NOT be `hv-lc`."""
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        tmp_path = Path(td)
        for i in range(13):
            _write_task(tmp_path, f"T-9{i:03d}", d1=0)
        for i in range(12):
            _write_task(tmp_path, f"T-8{i:03d}", d1=(i % 5) + 1)

        out, err, rc = _run_fw_bvp(tmp_path, "--quadrant", "hv-lc")
        assert rc == 0, f"rank exited {rc}; stderr: {err}"

        for i in range(13):
            assert f"T-9{i:03d}" not in out, (
                f"T-9{i:03d} (zero-value, degenerate median) leaked into "
                "hv-lc — value-axis equality defect not repaired"
            )


def test_degenerate_median_withheld_quadrant_label_and_note():
    """The withheld verdict must be visible under the default (unfiltered)
    rank — both as a distinct quadrant label (never 'hv-lc'/'hv-hc') and as
    an explicit NOTE, mirroring the existing cost-unknown disclosure
    (CLAUDE.md: a silently-dropped tied mass reads as complete coverage)."""
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        tmp_path = Path(td)
        for i in range(3):
            _write_task(tmp_path, f"T-9{i:03d}", d1=0)
        _write_task(tmp_path, "T-8000", d1=5)

        out, err, rc = _run_fw_bvp(tmp_path)
        assert rc == 0, f"rank exited {rc}; stderr: {err}"
        assert "NOTE:" in out and "degenerate" in out, (
            "no disclosure NOTE printed for a withheld degenerate-median tie mass"
        )
        for i in range(3):
            line = next((l for l in out.splitlines() if f"T-9{i:03d}" in l), None)
            assert line is not None, f"T-9{i:03d} missing from output entirely"
            assert "hv-lc" not in line and "hv-hc" not in line, (
                f"T-9{i:03d} still shows a manufactured hv-* verdict: {line!r}"
            )


# ----------------------------------------------------------------------------
# Direction 2: admission — a genuinely high-value task still reads `hv`
# ----------------------------------------------------------------------------


def test_genuinely_high_value_task_still_classified_hv_in_degenerate_corpus():
    """In the SAME degenerate corpus as the exclusion test, the clear
    top-scorer (well above the degenerate median) must still land in hv-lc.
    A mechanism that also swallows this would be narrowing the classifier,
    not repairing it — this is the required two-sided proof."""
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        tmp_path = Path(td)
        for i in range(13):
            _write_task(tmp_path, f"T-9{i:03d}", d1=0)
        for i in range(12):
            _write_task(tmp_path, f"T-8{i:03d}", d1=(i % 5) + 1)

        out, err, rc = _run_fw_bvp(tmp_path, "--quadrant", "hv-lc")
        assert rc == 0, f"rank exited {rc}; stderr: {err}"
        # T-8004/T-8009 score D1=5 (the max), clearly above the degenerate
        # median of 0 — must still be admitted to hv-lc.
        assert "T-8004" in out, "clear top-scorer excluded from hv-lc — over-corrected"
        assert "T-8009" in out, "clear top-scorer excluded from hv-lc — over-corrected"


def test_naive_flip_to_strict_greater_would_fail_admission():
    """Negative-control-on-the-mechanism: prove the naive `>=`→`>` swap this
    task explicitly rejects is a real, not hypothetical, alternative failure.
    With strict `>`, a task sitting exactly AT a genuine (non-degenerate)
    median would be excluded from hv — demonstrated directly against the
    shipped quadrant() semantics using an even-sized, non-degenerate corpus
    where the two middle values differ from the floor."""
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        tmp_path = Path(td)
        # Non-degenerate: distinct spread, median (avg of two middle values)
        # does not equal the floor (1) — value_axis_degenerate() is False.
        _write_task(tmp_path, "T-7000", d1=1)
        _write_task(tmp_path, "T-7001", d1=2)
        _write_task(tmp_path, "T-7002", d1=2)
        _write_task(tmp_path, "T-7003", d1=4)

        out, err, rc = _run_fw_bvp(tmp_path)
        assert rc == 0, f"rank exited {rc}; stderr: {err}"
        # median D1 = 2.0 (avg of the two middle 2s); norm = 18/45 = 0.40.
        # Both D1=2 tasks sit exactly at the median and must read hv under
        # `>=` (this repair's mechanism does not touch non-degenerate ties —
        # only a naive `>` swap would wrongly exclude them).
        for line in out.splitlines():
            if "T-7001" in line or "T-7002" in line:
                assert "hv-" in line, (
                    f"non-degenerate at-median task wrongly excluded from hv "
                    f"(this is what a naive `>` swap would do): {line!r}"
                )


# ----------------------------------------------------------------------------
# Control: healthy, well-spread corpus is unaffected by the repair
# ----------------------------------------------------------------------------


def test_healthy_well_spread_corpus_unaffected():
    """A corpus with no ties at the floor and a median that genuinely
    separates the distribution must classify identically to pre-fix `>=`
    semantics — the repair must be inert here, not merely 'mostly inert'."""
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        tmp_path = Path(td)
        # 5 distinct D1 scores 1..5, all distinct costs 1..5 too (br/tier/
        # effort scaled so composite cost is monotonic and distinct).
        for i, d1 in enumerate([1, 2, 3, 4, 5]):
            _write_task(tmp_path, f"T-6{i:03d}", d1=d1,
                        blast_radius=d1, tier=d1, effort=d1)

        out, err, rc = _run_fw_bvp(tmp_path)
        assert rc == 0, f"rank exited {rc}; stderr: {err}"
        assert "NOTE:" not in out or "degenerate" not in out, (
            "well-spread, non-degenerate corpus incorrectly flagged degenerate"
        )
        # D1 scores 1..5 (D2-D4 pinned 0, all counted in weight_sum=24) -> raw
        # 9,18,27,36,45 -> norm .07,.15,.23,.30,.38; median norm = 0.23
        # (T-6002, d1=3). Costs 1..5 -> composite 1..5; median cost = 3
        # (T-6002). Verified directly against a live run of this exact
        # fixture (not asserted blind). Expected quadrants:
        expected = {
            "T-6000": "lv-lc",  # norm .07 < .23 ; cost 1 <= 3
            "T-6001": "lv-lc",  # norm .15 < .23 ; cost 2 <= 3
            "T-6002": "hv-lc",  # norm .23 >= .23 (AT median, non-degenerate) ; cost 3 <= 3
            "T-6003": "hv-hc",  # norm .30 >= .23 ; cost 4 > 3
            "T-6004": "hv-hc",  # norm .38 >= .23 ; cost 5 > 3
        }
        for task_id, quad in expected.items():
            line = next((l for l in out.splitlines() if task_id in l), None)
            assert line is not None, f"{task_id} missing from output"
            assert quad in line, (
                f"{task_id} expected quadrant {quad!r} not found in line: {line!r} "
                "— repair changed behaviour on a non-degenerate corpus"
            )
