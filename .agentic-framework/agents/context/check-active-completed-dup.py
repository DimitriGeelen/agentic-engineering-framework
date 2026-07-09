#!/usr/bin/env python3
"""
T-2517: active<->completed same-id task duplicate write-time guard (T-2121 prong 1).

Closes the write-time gap in the divergence class RCA'd by T-2091: a manual
Write that creates `.tasks/completed/T-NNNN-*.md` while
`.tasks/active/T-NNNN-*.md` already exists (or vice-versa) puts the same task
id in both directories simultaneously. The existing control (G-052 STRUCTURE
audit) only detects this after the fact, at audit time — this hook blocks it
at the point of creation.

Activation:
    PreToolUse Write|Edit|MultiEdit on .tasks/{active,completed}/T-*.md.

Behavior:
    - Only fires when the target file does not yet exist on disk (i.e. this
      write would CREATE a new file, not edit an existing one). Edits to an
      already-existing file (including an already-duplicated one, e.g. during
      cleanup) are never blocked by this hook.
    - The legitimate `fw task update --status work-completed` transition uses
      `git mv`/`mv` via a Bash subprocess, not the Write/Edit tool — it never
      reaches this hook, so no special-case bypass is needed for it.
    - If the sibling directory (completed when writing active, active when
      writing completed) already has a file matching `T-NNNN-*.md` for the
      same id: block (exit 2) under agent control, advisory-only otherwise.

Exit codes:
    0 — allow (no sibling duplicate, override active, or not agent-controlled)
    2 — block (sibling duplicate detected, under agent control, no override)

Override: FW_ALLOW_ACTIVE_COMPLETED_DUP=1 — Tier-2 logged bypass.

Origin: T-2121 GO prong 1 (docs/reports/T-2121-tasks-dir-divergence-prevention.md).
Analogue: agents/context/check-arc-id.py (T-1849).
"""
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
_FRAMEWORK_ROOT = _SCRIPT_DIR.parent.parent
if str(_FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(_FRAMEWORK_ROOT))

from lib.hook_paths import reanchor_project_root  # noqa: E402

_TASK_PATH_RE = re.compile(r"/\.tasks/(active|completed)/(T-\d+)-[^/]*\.md$")


def _log_bypass(project_root: Path, task_id: str, file_path: str) -> None:
    log_dir = project_root / ".context" / "working"
    try:
        log_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        return
    log_file = log_dir / ".gate-bypass-log.yaml"
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    def _q(v: str) -> str:
        return str(v).replace("'", "''")

    entry = (
        f"- timestamp: '{_q(ts)}'\n"
        f"  task: '{_q(task_id)}'\n"
        f"  flag: 'FW_ALLOW_ACTIVE_COMPLETED_DUP'\n"
        f"  caller: 'check-active-completed-dup'\n"
        f"  file: '{_q(file_path)}'\n"
    )
    try:
        with log_file.open("a") as f:
            f.write(entry)
    except OSError:
        pass


def _emit_block(task_id: str, file_path: str, sibling_dir: str, sibling_match: Path) -> None:
    sys.stderr.write("\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("  ACTIVE/COMPLETED DUPLICATE — write-time guard (T-2121 prong 1)\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("\n")
    sys.stderr.write(f"  Task:      {task_id}\n")
    sys.stderr.write(f"  Creating:  {file_path}\n")
    sys.stderr.write(f"  Conflict:  {sibling_match} (already in .tasks/{sibling_dir}/)\n")
    sys.stderr.write("\n")
    sys.stderr.write(f"  {task_id} cannot exist in both .tasks/active/ and .tasks/completed/\n")
    sys.stderr.write("  at the same time — this is the T-2091 divergence class (stray copy\n")
    sys.stderr.write("  was masked by metadata churn for ~7 days, then FAILed a pre-push\n")
    sys.stderr.write("  audit and stranded a handover commit).\n")
    sys.stderr.write("\n")
    sys.stderr.write("  To proceed, choose ONE:\n")
    sys.stderr.write(f"    1. Use `fw task update {task_id} --status work-completed` (the\n")
    sys.stderr.write("       git-mv path — moves the file, never leaves both copies present), OR\n")
    sys.stderr.write(f"    2. Remove the stale .tasks/{sibling_dir}/ copy first if it's an\n")
    sys.stderr.write("       orphan (verify which copy is canonical before deleting), OR\n")
    sys.stderr.write("    3. Override (logged Tier-2): FW_ALLOW_ACTIVE_COMPLETED_DUP=1 ...\n")
    sys.stderr.write("\n")
    sys.stderr.write("  Origin: T-2091 RCA → T-2121 GO prong 1.\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0  # malformed input — fail open

    tool_name = data.get("tool_name", "")
    if tool_name not in ("Edit", "Write", "MultiEdit"):
        return 0

    ti = data.get("tool_input", {}) or {}
    file_path = ti.get("file_path") or ti.get("notebook_path") or ""

    m = _TASK_PATH_RE.search(file_path)
    if not m:
        return 0

    this_dir, task_id = m.group(1), m.group(2)
    sibling_dir = "completed" if this_dir == "active" else "active"

    # Only fires on genuine creation (PreToolUse runs before the write lands,
    # so an existing file means this call is editing/overwriting it — not
    # introducing a new duplicate).
    if Path(file_path).exists():
        return 0

    project_root = reanchor_project_root(data, os.environ.get("PROJECT_ROOT", "."))
    sibling_glob_dir = project_root / ".tasks" / sibling_dir
    matches = sorted(sibling_glob_dir.glob(f"{task_id}-*.md")) if sibling_glob_dir.is_dir() else []
    if not matches:
        return 0

    sibling_match = matches[0]

    if os.environ.get("FW_ALLOW_ACTIVE_COMPLETED_DUP") == "1":
        _log_bypass(project_root, task_id, file_path)
        sys.stderr.write(
            f"NOTE: {task_id} already exists in .tasks/{sibling_dir}/ but write "
            f"allowed via FW_ALLOW_ACTIVE_COMPLETED_DUP=1 — logged.\n"
        )
        return 0

    under_agent_control = (
        os.environ.get("CLAUDECODE") == "1"
        or bool(os.environ.get("AI_AGENT", "").strip())
    )
    if not under_agent_control:
        sys.stderr.write(
            f"NOTE: {task_id} already exists in .tasks/{sibling_dir}/ "
            f"(would block under agent control): {sibling_match}\n"
        )
        return 0

    _emit_block(task_id, file_path, sibling_dir, sibling_match)
    return 2


if __name__ == "__main__":
    sys.exit(main())
