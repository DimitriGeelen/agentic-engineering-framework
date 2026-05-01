"""T-1643/W1+W2+W4 — task-type derivation in fw termlink dispatch / spawn.

Pins three behaviors:
  1. _derive_task_type reads workflow_type from focused task file.
  2. cmd_spawn / cmd_dispatch accept --task-type flag.
  3. Dispatch worker meta.json includes task_type/model_used/fallback_used.

Tests source agents/termlink/termlink.sh helpers directly. They do not
spawn real termlink sessions (those require a live binary + hub).
"""

import json
import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
TERMLINK_SH = REPO_ROOT / "agents" / "termlink" / "termlink.sh"


def _run_helper(project_root, helper_call):
    """Source termlink.sh and run a helper function, returning stdout."""
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(project_root)
    env["FRAMEWORK_ROOT"] = str(REPO_ROOT)
    # Source termlink.sh inside a subshell that ignores its trailing
    # "wrong-call" exit; we only want the function definitions.
    cmd = (
        f'set +e; source "{TERMLINK_SH}" 2>/dev/null; '
        f'set -e; {helper_call}'
    )
    return subprocess.run(
        ["bash", "-c", cmd], env=env, capture_output=True, text=True
    )


def _seed(tmp_path, current_task, workflow_type):
    """Create minimal focus.yaml + task file for derivation."""
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text(f"framework_path: {REPO_ROOT}\n")
    (tmp_path / ".context" / "working" / "focus.yaml").write_text(
        f"current_task: {current_task}\n"
    )
    (tmp_path / ".tasks" / "active" / f"{current_task}-x.md").write_text(
        f"---\nid: {current_task}\nname: x\nstatus: started-work\n"
        f"workflow_type: {workflow_type}\nhorizon: now\n---\n"
    )
    return tmp_path


def test_derive_task_type_returns_workflow_type_of_focused_task(tmp_path):
    p = _seed(tmp_path, "T-9001", "build")
    r = _run_helper(p, "_derive_task_type")
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "build"


def test_derive_task_type_handles_inception(tmp_path):
    p = _seed(tmp_path, "T-9002", "inception")
    r = _run_helper(p, "_derive_task_type")
    assert r.returncode == 0
    assert r.stdout.strip() == "inception"


def test_derive_task_type_empty_when_no_focus(tmp_path):
    """No focus.yaml → empty derivation, no error."""
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text("")
    r = _run_helper(tmp_path, "_derive_task_type")
    assert r.returncode == 0
    assert r.stdout.strip() == ""


def test_derive_task_type_empty_when_focus_null(tmp_path):
    """current_task: null → empty derivation."""
    (tmp_path / ".context" / "working").mkdir(parents=True)
    (tmp_path / ".framework.yaml").write_text("")
    (tmp_path / ".context" / "working" / "focus.yaml").write_text(
        "current_task: null\n"
    )
    r = _run_helper(tmp_path, "_derive_task_type")
    assert r.returncode == 0
    assert r.stdout.strip() == ""


def test_resolve_dispatch_model_explicit_wins(tmp_path):
    """Explicit --model overrides any config default."""
    (tmp_path / ".framework.yaml").write_text("DISPATCH_MODEL_DEFAULT: opus\n")
    r = _run_helper(tmp_path, '_resolve_dispatch_model "haiku" "build"')
    assert r.returncode == 0
    assert r.stdout.strip() == "haiku"


def test_resolve_dispatch_model_per_task_type_override(tmp_path):
    """DISPATCH_MODEL_FOR_BUILD beats DISPATCH_MODEL_DEFAULT."""
    (tmp_path / ".framework.yaml").write_text(
        "DISPATCH_MODEL_DEFAULT: opus\nDISPATCH_MODEL_FOR_BUILD: haiku\n"
    )
    r = _run_helper(tmp_path, '_resolve_dispatch_model "" "build"')
    assert r.returncode == 0
    assert r.stdout.strip() == "haiku"


def test_resolve_dispatch_model_falls_back_to_default(tmp_path):
    """No per-type override → DISPATCH_MODEL_DEFAULT."""
    (tmp_path / ".framework.yaml").write_text("DISPATCH_MODEL_DEFAULT: sonnet\n")
    r = _run_helper(tmp_path, '_resolve_dispatch_model "" "inception"')
    assert r.returncode == 0
    assert r.stdout.strip() == "sonnet"


def test_resolve_dispatch_model_empty_when_nothing_set(tmp_path):
    """No explicit, no config → empty string (caller decides default)."""
    (tmp_path / ".framework.yaml").write_text("")
    r = _run_helper(tmp_path, '_resolve_dispatch_model "" ""')
    assert r.returncode == 0
    assert r.stdout.strip() == ""


def test_dispatch_meta_json_format_pinned():
    """Pin the dispatch meta.json schema includes orchestrator-substrate keys.

    This is a static check on the heredoc — we don't spawn a real worker
    but we verify the source contains the new fields so a future refactor
    that drops them fails the test.
    """
    src = TERMLINK_SH.read_text()
    assert '"task_type"' in src, "meta.json missing task_type field"
    assert '"model_used"' in src, "meta.json missing model_used field"
    assert '"fallback_used"' in src, "meta.json missing fallback_used field"


def test_spawn_accepts_task_type_flag():
    """cmd_spawn parses --task-type. Static source check."""
    src = TERMLINK_SH.read_text()
    # Look for the flag handler in cmd_spawn (between cmd_spawn and cmd_exec)
    spawn_block = src.split("cmd_spawn() {", 1)[1].split("cmd_exec() {", 1)[0]
    assert "--task-type)" in spawn_block, "cmd_spawn missing --task-type handler"


def test_dispatch_accepts_task_type_flag():
    """cmd_dispatch parses --task-type. Static source check."""
    src = TERMLINK_SH.read_text()
    dispatch_block = src.split("cmd_dispatch() {", 1)[1].split("cmd_wait() {", 1)[0]
    assert "--task-type)" in dispatch_block, "cmd_dispatch missing --task-type handler"
