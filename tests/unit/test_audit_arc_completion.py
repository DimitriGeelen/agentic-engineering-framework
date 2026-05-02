"""T-1656 — `fw audit --section arc-completion` (G-062 mechanism #2).

Pins the detective check that catches "code-complete without arc closure":
when an arc accumulates ≥80% completed children without the arc itself being
explicitly closed via `fw arc close`, the audit must WARN.

Four fixtures:
  - empty registry           → 0 warns, 0 passes
  - in-progress arc 50%      → 0 warns (1 pass)
  - in-progress arc 90%      → 1 warn  (0 passes)
  - closed arc at 100%       → 0 warns (skipped)
"""

import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
FW = REPO_ROOT / "bin" / "fw"


def _run_audit(cwd):
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(cwd)
    env["FRAMEWORK_ROOT"] = str(REPO_ROOT)
    return subprocess.run(
        [str(FW), "audit", "--section", "arc-completion"],
        cwd=str(cwd), env=env, capture_output=True, text=True,
    )


def _seed_project(tmp_path):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".tasks" / "templates").mkdir(parents=True)
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".context" / "audits").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    # Minimal default template (audit checks for it).
    (tmp_path / ".tasks" / "templates" / "default.md").write_text("---\n---\n")
    return tmp_path


def _write_arc(tmp_path, arc_id, status, tasks):
    arcs_dir = tmp_path / ".context" / "arcs"
    arcs_dir.mkdir(parents=True, exist_ok=True)
    inner = ", ".join(f'"{t}"' for t in tasks)
    (arcs_dir / f"{arc_id}.yaml").write_text(
        f"id: {arc_id}\n"
        f"name: {arc_id} arc\n"
        f"status: {status}\n"
        f"anchor_task:\n"
        f"constituent_tasks: [{inner}]\n"
        f"created: 2026-05-01T00:00:00Z\n"
        f"closed_at: null\n"
        f"decision: null\n"
    )


def _write_task(tmp_path, tid, status):
    location = "completed" if status == "work-completed" else "active"
    (tmp_path / ".tasks" / location / f"{tid}-x.md").write_text(
        f"---\nid: {tid}\nname: {tid}\nstatus: {status}\nworkflow_type: build\nhorizon: now\n---\n"
    )


def test_arc_completion_empty_registry(tmp_path):
    """No arcs → no warns, no passes (just info)."""
    p = _seed_project(tmp_path)
    r = _run_audit(p)
    assert r.returncode in (0, 1), r.stderr
    out = r.stdout
    assert "ARC-COMPLETION CHECKS" in out
    assert "Arc registry empty" in out
    # No PASS or WARN lines specifically about arcs.
    arc_warns = sum(1 for line in out.splitlines() if line.startswith("[WARN]") and "Arc '" in line)
    arc_passes = sum(1 for line in out.splitlines() if line.startswith("[PASS]") and "Arc '" in line)
    assert arc_warns == 0
    assert arc_passes == 0


def test_arc_completion_below_threshold(tmp_path):
    """50%-complete in-progress arc → no warn, one pass."""
    p = _seed_project(tmp_path)
    _write_arc(p, "low", "in-progress", ["T-1", "T-2", "T-3", "T-4"])
    _write_task(p, "T-1", "work-completed")
    _write_task(p, "T-2", "work-completed")
    _write_task(p, "T-3", "started-work")
    _write_task(p, "T-4", "started-work")

    r = _run_audit(p)
    out = r.stdout
    arc_warns = sum(1 for line in out.splitlines() if line.startswith("[WARN]") and "Arc 'low'" in line)
    arc_passes = sum(1 for line in out.splitlines() if line.startswith("[PASS]") and "Arc 'low'" in line)
    assert arc_warns == 0, f"unexpected warn:\n{out}"
    assert arc_passes == 1, f"missing pass:\n{out}"


def test_arc_completion_above_threshold_warns(tmp_path):
    """≥80%-complete in-progress arc → WARN."""
    p = _seed_project(tmp_path)
    # 9/10 = 90%
    tasks = [f"T-{n}" for n in range(1, 11)]
    _write_arc(p, "hot", "in-progress", tasks)
    for n, t in enumerate(tasks, start=1):
        status = "work-completed" if n <= 9 else "started-work"
        _write_task(p, t, status)

    r = _run_audit(p)
    out = r.stdout
    arc_warns = sum(1 for line in out.splitlines() if line.startswith("[WARN]") and "Arc 'hot'" in line)
    assert arc_warns == 1, f"expected exactly 1 warn for 'hot' arc:\n{out}"
    # Mitigation must point at §Arc Completion Discipline / fw arc close.
    assert "fw arc close" in out
    assert "Arc Completion Discipline" in out


def test_arc_completion_closed_arc_skipped(tmp_path):
    """Closed arc with 100% completion → no warn, no pass (skipped)."""
    p = _seed_project(tmp_path)
    _write_arc(p, "done", "closed", ["T-1", "T-2"])
    _write_task(p, "T-1", "work-completed")
    _write_task(p, "T-2", "work-completed")

    r = _run_audit(p)
    out = r.stdout
    arc_warns = sum(1 for line in out.splitlines() if line.startswith("[WARN]") and "Arc 'done'" in line)
    arc_passes = sum(1 for line in out.splitlines() if line.startswith("[PASS]") and "Arc 'done'" in line)
    assert arc_warns == 0
    assert arc_passes == 0  # closed arcs don't emit PASS either


def test_arc_completion_runs_under_oe_daily(tmp_path):
    """T-1665: arc-completion must fire under `--section oe-daily` so the cron
    detective signal lands in production. Pre-T-1665 the section was guarded
    by `should_run_section "arc-completion"` only, which neither cron path
    invokes (cron uses `--section oe-daily` and `--section observations,gaps`).
    """
    p = _seed_project(tmp_path)
    tasks = [f"T-{n}" for n in range(1, 11)]
    _write_arc(p, "ringing", "in-progress", tasks)
    for n, t in enumerate(tasks, start=1):
        status = "work-completed" if n <= 9 else "started-work"
        _write_task(p, t, status)

    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(p)
    env["FRAMEWORK_ROOT"] = str(REPO_ROOT)
    r = subprocess.run(
        [str(FW), "audit", "--section", "oe-daily"],
        cwd=str(p), env=env, capture_output=True, text=True,
    )
    out = r.stdout
    assert "ARC-COMPLETION CHECKS" in out, (
        "arc-completion section header missing under oe-daily — fix never landed:\n" + out
    )
    arc_warns = sum(1 for line in out.splitlines() if line.startswith("[WARN]") and "Arc 'ringing'" in line)
    assert arc_warns == 1, f"expected the detective to fire under oe-daily:\n{out}"
