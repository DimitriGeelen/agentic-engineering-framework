#!/usr/bin/env python3
"""
T-2420: Task AC structure validation hook (implements T-2418 GO).

Closes structural silent-failure: `update-task.sh` parses `## Acceptance
Criteria` with `sed -n '/^## Acceptance Criteria/,/^## /p'`, which closes the
section at the NEXT `## ` heading. If `### Human` is placed AFTER an
intervening `## ` heading (e.g. `## Build summary`, `## Recommendation`), the
parser never sees it: `Human ACs: 0/0`, partial-complete branch never fires,
task moves to `completed/` carrying an unticked Human AC the human never sees.

Origin: T-2417 close cascade (S-2026-0616). The defect existed in the parser
unchanged for multi-year horizon; this hook prevents the *write-time*
introduction of the structural error at all 1900+ task-file edit sites.

Activation:
    PreToolUse Write|Edit|MultiEdit on .tasks/{active,completed}/T-*.md.
Receives stdin JSON from Claude Code:
    {"tool_name": ..., "tool_input": {file_path, content|old_string+new_string|edits}}

Semantics — no-worse-than grandfathering:
    Count malformed `### Human` headings in OLD vs NEW content. Block only when
    NEW count > OLD count (this edit introduced or worsened the structural
    error). Pre-existing offenders are not retroactively blocked; legitimate
    edits to grandfathered files pass through unchanged.

Exit codes:
    0 — allow
    2 — block under agent control ($CLAUDECODE=1 or AI_AGENT set)

Override:
    FW_ALLOW_AC_STRUCTURE_DRIFT=1 — bypass with Tier-2 log entry per T-1890.

Analogue: agents/context/check-inception-decisions.py (T-1984, G-066).
"""
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

_TASK_RE = re.compile(r"/\.tasks/(active|completed)/T-\d+")
_AC_RE = re.compile(r"^## Acceptance Criteria\b")
_H2_RE = re.compile(r"^## [^#]")
_HUMAN_RE = re.compile(r"^### Human\b")


def _derive_task_id(file_path: str) -> str:
    m = re.search(r"T-\d+", file_path)
    return m.group(0) if m else "unknown"


def _count_malformed_humans(content: str) -> tuple[int, list[int]]:
    """Return (count, line_numbers) of `### Human` headings outside the
    `## Acceptance Criteria` block.

    A heading is correctly placed when it appears between the first
    `## Acceptance Criteria` heading and the NEXT `## ` heading (same
    semantics as update-task.sh's sed range).
    """
    lines = content.splitlines()
    ac_start = None
    human_lines: list[int] = []
    h2_lines: list[int] = []
    for i, ln in enumerate(lines):
        if _AC_RE.match(ln):
            if ac_start is None:
                ac_start = i
        elif _H2_RE.match(ln):
            h2_lines.append(i)
        if _HUMAN_RE.match(ln):
            human_lines.append(i)

    if not human_lines:
        return (0, [])
    if ac_start is None:
        # ### Human exists but no ## AC at all — every Human is malformed.
        return (len(human_lines), human_lines)

    nexts = [n for n in h2_lines if n > ac_start]
    next_h2 = min(nexts) if nexts else len(lines)
    bad = [h for h in human_lines if not (ac_start < h < next_h2)]
    return (len(bad), bad)


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


def _old_content(file_path: str) -> str:
    try:
        return Path(file_path).read_text()
    except (FileNotFoundError, OSError):
        return ""


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


def _emit_block(
    task_id: str, file_path: str, new_bad: list[int], old_count: int
) -> None:
    sys.stderr.write("\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("  TASK AC STRUCTURE ERROR — T-2420 guard\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("\n")
    sys.stderr.write(f"  Task:  {task_id}\n")
    sys.stderr.write(f"  File:  {file_path}\n")
    sys.stderr.write("\n")
    sys.stderr.write(
        f"  This edit places {len(new_bad)} `### Human` heading(s) OUTSIDE the\n"
        f"  `## Acceptance Criteria` block (line(s): {new_bad}).\n"
    )
    if old_count > 0:
        sys.stderr.write(
            f"  Pre-existing offender count: {old_count}; this edit would raise it.\n"
        )
    sys.stderr.write("\n")
    sys.stderr.write(
        "  Why this matters (origin: T-2417, S-2026-0616):\n"
        "    update-task.sh extracts `## Acceptance Criteria` with\n"
        "      sed -n '/^## Acceptance Criteria/,/^## /p'\n"
        "    which CLOSES the section at the NEXT `## ` heading. Any `### Human`\n"
        "    placed after an intervening `## Build summary`, `## Recommendation`,\n"
        "    etc. is INVISIBLE to the parser: Human ACs report as 0/0 and the\n"
        "    partial-complete branch never fires.\n"
    )
    sys.stderr.write("\n")
    sys.stderr.write("  Correct layout:\n")
    sys.stderr.write("    ## Acceptance Criteria\n")
    sys.stderr.write("    ### Agent\n")
    sys.stderr.write("    - [ ] ...\n")
    sys.stderr.write("    ### Human          ← INSIDE the AC block\n")
    sys.stderr.write("    - [ ] [REVIEW] ...\n")
    sys.stderr.write("    ## Recommendation  ← any other ## AFTER the AC block\n")
    sys.stderr.write("\n")
    sys.stderr.write(
        "  To override (Tier-2 logged): FW_ALLOW_AC_STRUCTURE_DRIFT=1\n"
    )
    sys.stderr.write("══════════════════════════════════════════════════════════\n")


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    tool_name = data.get("tool_name", "")
    if tool_name not in ("Edit", "Write", "MultiEdit"):
        return 0

    ti = data.get("tool_input", {}) or {}
    file_path = ti.get("file_path") or ti.get("notebook_path") or ""
    if not _TASK_RE.search(file_path):
        return 0
    if not file_path.endswith(".md"):
        return 0

    new_content = _compute_new_content(tool_name, ti, file_path)
    if new_content is None:
        return 0

    old_content = _old_content(file_path)
    old_count, _ = _count_malformed_humans(old_content)
    new_count, new_bad = _count_malformed_humans(new_content)

    if new_count <= old_count:
        return 0

    project_root = Path(os.environ.get("PROJECT_ROOT", "."))
    task_id = _derive_task_id(file_path)

    if os.environ.get("FW_ALLOW_AC_STRUCTURE_DRIFT") == "1":
        _log_bypass(project_root, task_id, file_path)
        sys.stderr.write(
            f"NOTE: task AC structure error in {task_id} — write allowed via "
            f"FW_ALLOW_AC_STRUCTURE_DRIFT=1 (logged).\n"
        )
        return 0

    under_agent = (
        os.environ.get("CLAUDECODE") == "1"
        or bool(os.environ.get("AI_AGENT", "").strip())
    )
    if not under_agent:
        sys.stderr.write(
            f"NOTE: task AC structure error in {task_id} at line(s) {new_bad} "
            f"(would block under agent control).\n"
        )
        return 0

    _emit_block(task_id, file_path, new_bad, old_count)
    return 2


if __name__ == "__main__":
    sys.exit(main())
