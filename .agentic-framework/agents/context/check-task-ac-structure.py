#!/usr/bin/env python3
"""
T-2420: task AC structure validation hook.

Closes structural silent-failure class: `### Human` heading outside `## Acceptance Criteria`
causes the partial-complete parser to miss Human ACs.

Activation:
    PreToolUse Write|Edit|MultiEdit on .tasks/{active,completed}/T-*.md.
Receives stdin JSON from Claude Code:
    {"tool_name": ..., "tool_input": {file_path, content|old_string+new_string|edits}}

Behavior:
    - Compute new content (Write/Edit/MultiEdit).
    - Parse task for `### Human` headings.
    - If any `### Human` is outside the `## Acceptance Criteria` block → block (exit 2).
    - Grandfather logic: count malformed `### Human` in old vs new; block only if new > old.

Exit codes:
    0 — allow
    2 — block (structural error, under agent control, no override)

Override:
    FW_ALLOW_AC_STRUCTURE_DRIFT=1 — bypass with Tier-2 log entry.

Origin: T-2418 GO; T-2420 build. Analogue: agents/context/check-inception-decisions.py.
"""
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# Resolve lib/ relative to this script
_SCRIPT_DIR = Path(__file__).resolve().parent
_FRAMEWORK_ROOT = _SCRIPT_DIR.parent.parent
if str(_FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(_FRAMEWORK_ROOT))

from lib.hook_paths import reanchor_project_root  # noqa: E402

_TASK_RE = re.compile(r"/\.tasks/(active|completed)/T-\d+")


def _derive_task_id(file_path: str) -> str:
    m = re.search(r"T-\d+", file_path)
    return m.group(0) if m else "unknown"


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
        f"  flag: 'FW_ALLOW_AC_STRUCTURE_DRIFT'\n"
        f"  caller: 'check-task-ac-structure'\n"
        f"  file: '{_q(file_path)}'\n"
    )
    try:
        with log_file.open("a") as f:
            f.write(entry)
    except OSError:
        pass


def _compute_new_content(tool_name: str, ti: dict, file_path: str) -> str | None:
    try:
        old_content = Path(file_path).read_text()
    except (FileNotFoundError, OSError):
        old_content = ""

    if tool_name == "Write":
        return ti.get("content", "")

    if tool_name == "Edit":
        old_str = ti.get("old_string", "")
        new_str = ti.get("new_string", "")
        if not old_str:
            return None
        if ti.get("replace_all", False):
            return old_content.replace(old_str, new_str)
        return old_content.replace(old_str, new_str, 1)

    if tool_name == "MultiEdit":
        content = old_content
        for edit in ti.get("edits", []):
            o = edit.get("old_string", "")
            n = edit.get("new_string", "")
            if not o:
                continue
            if edit.get("replace_all", False):
                content = content.replace(o, n)
            else:
                content = content.replace(o, n, 1)
        return content

    return None


def _count_malformed_human_headers(content: str) -> int:
    """
    Count `### Human` headers that appear OUTSIDE the `## Acceptance Criteria` block.
    
    The AC block spans from `## Acceptance Criteria` to the next `## ` heading (or EOF).
    A `### Human` inside this block is correct. Outside it is malformed.
    """
    lines = content.splitlines()
    
    # Find the AC block boundaries
    ac_start = None
    ac_end = None
    
    for i, line in enumerate(lines):
        if line.startswith("## Acceptance Criteria"):
            ac_start = i
        elif ac_start is not None and line.startswith("## ") and not line.startswith("### "):
            ac_end = i
            break
    
    # If no AC block found, all `### Human` are malformed
    if ac_start is None:
        count = 0
        for line in lines:
            if line.startswith("### Human"):
                count += 1
        return count
    
    # If AC block found but no end, it extends to EOF
    if ac_end is None:
        ac_end = len(lines)
    
    # Count `### Human` outside the AC block
    count = 0
    for i, line in enumerate(lines):
        if line.startswith("### Human"):
            if i < ac_start or i >= ac_end:
                count += 1
    
    return count


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

    if not _TASK_RE.search(file_path):
        return 0
    if not file_path.endswith(".md"):
        return 0

    project_root = reanchor_project_root(data, os.environ.get("PROJECT_ROOT", "."))

    # Get old content
    try:
        old_content = Path(file_path).read_text()
    except (FileNotFoundError, OSError):
        old_content = ""

    new_content = _compute_new_content(tool_name, ti, file_path)
    if new_content is None:
        return 0

    task_id = _derive_task_id(file_path)
    override_active = os.environ.get("FW_ALLOW_AC_STRUCTURE_DRIFT") == "1"

    # Grandfather logic: count malformed headers in old vs new
    old_count = _count_malformed_human_headers(old_content)
    new_count = _count_malformed_human_headers(new_content)

    # Only block if the edit INTRODUCES or WORSENS malformation
    if new_count > old_count:
        if override_active:
            _log_bypass(project_root, task_id, file_path)
            sys.stderr.write(
                f"NOTE: {task_id} has `### Human` outside AC block but "
                f"write allowed via FW_ALLOW_AC_STRUCTURE_DRIFT=1 — logged.\n"
            )
            return 0

        under_agent = (
            os.environ.get("CLAUDECODE") == "1"
            or bool(os.environ.get("AI_AGENT", "").strip())
        )
        if not under_agent:
            sys.stderr.write(
                f"NOTE: {task_id} has `### Human` outside AC block "
                f"(would block under agent control).\n"
            )
            return 0

        _emit_block_message(task_id, file_path, new_count, old_count)
        return 2

    return 0


def _emit_block_message(
    task_id: str, file_path: str, new_count: int, old_count: int
) -> None:
    sys.stderr.write("\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("  TASK AC STRUCTURE ERROR — T-2420 guard\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("\n")
    sys.stderr.write(f"  Task:  {task_id}\n")
    sys.stderr.write(f"  File:  {file_path}\n")
    sys.stderr.write("\n")
    sys.stderr.write(f"  Old count: {old_count}\n")
    sys.stderr.write(f"  New count: {new_count}\n")
    sys.stderr.write("\n")
    sys.stderr.write("  The `### Human` header MUST appear inside the\n")
    sys.stderr.write("  `## Acceptance Criteria` section, not after it.\n")
    sys.stderr.write("\n")
    sys.stderr.write("  Correct structure:\n")
    sys.stderr.write("    ## Acceptance Criteria\n")
    sys.stderr.write("    ### Agent\n")
    sys.stderr.write("    - [ ] ...\n")
    sys.stderr.write("    ### Human\n")
    sys.stderr.write("    - [ ] ...\n")
    sys.stderr.write("    ## Next Section  ← ends AC block\n")
    sys.stderr.write("\n")
    sys.stderr.write("  To override (Tier-2 logged): FW_ALLOW_AC_STRUCTURE_DRIFT=1\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")


if __name__ == "__main__":
    sys.exit(main())
