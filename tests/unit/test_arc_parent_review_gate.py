"""T-1657 — Arc-parent review gate (G-062 mechanism #3).

When `fw task review T-XXX` is invoked on a task that is the anchor of an
in-progress arc OR carries an `arc-parent` tag, lib/review.sh _arc_parent_gate
must print the three §Arc Completion Discipline questions BEFORE the URL.

Four cases:
  1. Anchor of in-progress arc                → banner
  2. Tagged `arc-parent` but no anchor        → banner
  3. Regular task                             → no banner
  4. Anchor of CLOSED arc                     → no banner (already shipped)
"""

import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
REVIEW_SH = REPO_ROOT / "lib" / "review.sh"
BANNER_RE = "ARC COMPLETION CHECK"


def _run_gate(project_root, task_id, task_file):
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(project_root)
    env["FRAMEWORK_ROOT"] = str(REPO_ROOT)
    env["YELLOW"] = ""
    env["NC"] = ""
    cmd = f'source "{REVIEW_SH}" 2>/dev/null; _arc_parent_gate "{task_id}" "{task_file}"'
    return subprocess.run(
        ["bash", "-c", cmd], env=env, capture_output=True, text=True
    )


def _seed(tmp_path):
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".context" / "arcs").mkdir(parents=True)
    return tmp_path


def _write_arc(p, arc_id, status, anchor):
    (p / ".context" / "arcs" / f"{arc_id}.yaml").write_text(
        f"id: {arc_id}\nname: {arc_id}\nstatus: {status}\n"
        f"anchor_task: {anchor}\nconstituent_tasks: []\n"
    )


def _write_task(p, tid, tags="[]"):
    f = p / ".tasks" / "active" / f"{tid}-x.md"
    f.write_text(
        f"---\nid: {tid}\nname: {tid}\nstatus: started-work\n"
        f"workflow_type: build\nhorizon: now\ntags: {tags}\n---\n"
    )
    return f


def test_anchor_of_in_progress_arc_emits_banner(tmp_path):
    p = _seed(tmp_path)
    tf = _write_task(p, "T-9001")
    _write_arc(p, "alpha", "in-progress", "T-9001")

    r = _run_gate(p, "T-9001", str(tf))
    assert r.returncode == 0, r.stderr
    assert BANNER_RE in r.stdout
    assert "alpha" in r.stdout


def test_arc_parent_tag_emits_banner(tmp_path):
    p = _seed(tmp_path)
    tf = _write_task(p, "T-9002", tags='["arc-parent"]')

    r = _run_gate(p, "T-9002", str(tf))
    assert r.returncode == 0
    assert BANNER_RE in r.stdout


def test_regular_task_no_banner(tmp_path):
    p = _seed(tmp_path)
    tf = _write_task(p, "T-9003", tags='["build"]')

    r = _run_gate(p, "T-9003", str(tf))
    assert r.returncode == 0
    assert BANNER_RE not in r.stdout


def test_anchor_of_closed_arc_no_banner(tmp_path):
    """Already-shipped arcs should not re-trigger the gate."""
    p = _seed(tmp_path)
    tf = _write_task(p, "T-9004")
    _write_arc(p, "shipped", "closed", "T-9004")

    r = _run_gate(p, "T-9004", str(tf))
    assert r.returncode == 0
    assert BANNER_RE not in r.stdout
