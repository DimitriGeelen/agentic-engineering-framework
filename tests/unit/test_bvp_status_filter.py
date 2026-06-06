"""T-2223: pin `fw bvp` rank actionable-only default + --include-completed opt-in.

Companion to `test_bvp_cli_rank_proposed.py` (T-1938 proposed-fallback contract).
This file pins the OTHER sovereignty default: rank lists actionable tasks
("what should I work on next"), not the archival sweep. work-completed rows
are skipped unless the operator explicitly opts in via `--include-completed`.

Origin: S-2026-0606-01XX HV-LC survey surfaced T-2074 / T-2002 / T-2196 (all
work-completed) inside `fw bvp --quadrant hv-lc --include-proposed` output.
Operator standing HV-LC directive was unreliable until this filter shipped.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def _write_task(tmp_path, task_id, status, scores, subdir="active"):
    """Write a minimal task file with the given status + bvp_scores.

    T-2224: ``subdir`` selects which .tasks/ directory the file lands in —
    ``active`` (default, T-2223 status leg) or ``completed`` (T-2224 directory
    leg, simulating L-390 drift where status field wasn't updated on git mv).
    """
    tasks_active = tmp_path / ".tasks" / "active"
    tasks_completed = tmp_path / ".tasks" / "completed"
    tasks_active.mkdir(parents=True, exist_ok=True)
    tasks_completed.mkdir(exist_ok=True)
    lines = [
        "---",
        f"id: {task_id}",
        f"name: \"{task_id} test\"",
        f"status: {status}",
        "workflow_type: build",
        "owner: agent",
        "horizon: now",
        "bvp_scores:",
    ]
    for k, v in scores.items():
        lines.append(f"  {k}: {v}")
    lines.append("---")
    lines.append("body")
    target_dir = tasks_completed if subdir == "completed" else tasks_active
    (target_dir / f"{task_id}-test.md").write_text("\n".join(lines) + "\n")


def _run_fw_bvp(tmp_path, *args):
    """Invoke `bin/fw bvp` against the tmp PROJECT_ROOT (synthetic repo)."""
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(tmp_path)
    # Minimal policy/value-drivers.yaml so load_policy() succeeds.
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
# Default: actionable-only (work-completed excluded)
# ----------------------------------------------------------------------------


def test_default_rank_excludes_work_completed(tmp_path):
    """T-2223 sovereignty default: `fw bvp` lists only non-work-completed rows."""
    _write_task(tmp_path, "T-99101", "started-work",
                {"D1": 5, "D2": 5, "D3": 5, "D4": 5})
    _write_task(tmp_path, "T-99102", "work-completed",
                {"D1": 5, "D2": 5, "D3": 5, "D4": 5})
    out, _err, rc = _run_fw_bvp(tmp_path)
    assert rc == 0, f"rank exited {rc}; stderr: {_err}"
    assert "T-99101" in out, "started-work row should be in default rank"
    assert "T-99102" not in out, (
        "work-completed row leaked into default rank — T-2223 filter missing"
    )


def test_quadrant_filter_also_excludes_work_completed(tmp_path):
    """The --quadrant path threads through cmd_rank too; same filter applies."""
    _write_task(tmp_path, "T-99103", "started-work",
                {"D1": 5, "D2": 5, "D3": 5, "D4": 5})
    _write_task(tmp_path, "T-99104", "work-completed",
                {"D1": 5, "D2": 5, "D3": 5, "D4": 5})
    out, _err, rc = _run_fw_bvp(tmp_path, "--quadrant", "hv-lc")
    assert rc == 0, f"rank exited {rc}; stderr: {_err}"
    # Either T-99103 appears (it's in hv-lc) or the "no matches" path fires —
    # both are valid outcomes. What MUST be true: T-99104 (work-completed)
    # never appears.
    assert "T-99104" not in out, (
        "work-completed row leaked into --quadrant rank — T-2223 filter "
        "didn't thread through the quadrant code path"
    )


# ----------------------------------------------------------------------------
# Opt-in: --include-completed restores the archival sweep
# ----------------------------------------------------------------------------


def test_include_completed_flag_restores_work_completed(tmp_path):
    """`fw bvp --include-completed` opts back into the archival sweep semantic."""
    _write_task(tmp_path, "T-99105", "started-work",
                {"D1": 5, "D2": 5, "D3": 5, "D4": 5})
    _write_task(tmp_path, "T-99106", "work-completed",
                {"D1": 5, "D2": 5, "D3": 5, "D4": 5})
    out, _err, rc = _run_fw_bvp(tmp_path, "--include-completed")
    assert rc == 0, f"rank exited {rc}; stderr: {_err}"
    assert "T-99105" in out, "started-work row missing under --include-completed"
    assert "T-99106" in out, (
        "--include-completed did NOT restore work-completed rows — flag broken"
    )


def test_include_completed_with_quadrant_filter(tmp_path):
    """--include-completed threads through --quadrant too (both call sites)."""
    _write_task(tmp_path, "T-99107", "work-completed",
                {"D1": 5, "D2": 5, "D3": 5, "D4": 5})
    out, _err, rc = _run_fw_bvp(
        tmp_path, "--quadrant", "hv-lc", "--include-completed"
    )
    assert rc == 0, f"rank exited {rc}; stderr: {_err}"
    # With only one task, it's the only candidate — either appears in hv-lc
    # or "No tasks match" fires depending on median maths. Either way: if
    # --include-completed didn't thread to the --quadrant call site, the
    # task would be silently filtered out by status BEFORE the quadrant logic
    # — which would print "No tasks have `bvp_scores:` set yet" or similar.
    # We assert the work-completed task is *considered* (appears OR the
    # output is the quadrant-empty message, not the no-scores message).
    assert "No tasks have" not in out, (
        "work-completed task was status-filtered before quadrant logic "
        "ran — --include-completed didn't reach the --quadrant call site"
    )


# ----------------------------------------------------------------------------
# Help-text discoverability
# ----------------------------------------------------------------------------


def test_help_documents_include_completed(tmp_path):
    out, _err, rc = _run_fw_bvp(tmp_path, "--help")
    assert rc == 0
    assert "--include-completed" in out, (
        "usage() does not document --include-completed — discoverability gap"
    )


# ----------------------------------------------------------------------------
# T-2224: directory leg — L-390 drift case
# ----------------------------------------------------------------------------
#
# T-2196 was the canonical evidence: file lives in .tasks/completed/ but the
# frontmatter `status:` field still says `started-work` (L-390 drift — git mv
# moved the file but no `fw task update --status work-completed` ran). T-2223's
# status filter doesn't catch this; T-2224 closes the directory leg.


def test_default_rank_excludes_completed_dir_drift(tmp_path):
    """T-2224 directory leg: file in completed/ with stale status is excluded."""
    _write_task(tmp_path, "T-99201", "started-work",
                {"D1": 5, "D2": 5, "D3": 5, "D4": 5}, subdir="active")
    _write_task(tmp_path, "T-99202", "started-work",
                {"D1": 5, "D2": 5, "D3": 5, "D4": 5}, subdir="completed")
    out, _err, rc = _run_fw_bvp(tmp_path)
    assert rc == 0, f"rank exited {rc}; stderr: {_err}"
    assert "T-99201" in out, "active/ task should be in default rank"
    assert "T-99202" not in out, (
        "completed/ task with stale status leaked into default rank — "
        "T-2224 directory leg missing (status filter alone doesn't catch L-390)"
    )


def test_include_completed_restores_dir_drift(tmp_path):
    """--include-completed restores L-390-drift rows (parity with status leg)."""
    _write_task(tmp_path, "T-99203", "started-work",
                {"D1": 5, "D2": 5, "D3": 5, "D4": 5}, subdir="active")
    _write_task(tmp_path, "T-99204", "started-work",
                {"D1": 5, "D2": 5, "D3": 5, "D4": 5}, subdir="completed")
    out, _err, rc = _run_fw_bvp(tmp_path, "--include-completed")
    assert rc == 0, f"rank exited {rc}; stderr: {_err}"
    assert "T-99203" in out, "active/ task missing under --include-completed"
    assert "T-99204" in out, (
        "--include-completed did NOT restore directory-drift row — "
        "T-2224 OR-clause wasn't gated by include_completed"
    )
