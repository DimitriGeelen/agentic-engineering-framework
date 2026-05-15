#!/usr/bin/env python3
"""
T-1731: Human-AC tick guard hook.

Closes G2 from T-1729 meta-RCA. Blocks the agent from toggling checkboxes
under the `### Human` heading of any task file in .tasks/*.md. CLAUDE.md
rule: "NEVER check a `### Human` AC. Only the human may verify and check
these boxes." This hook makes that structural.

Activation:
    PreToolUse Write|Edit on .tasks/*.md (any subdirectory).
Receives stdin JSON from Claude Code:
    {"tool_name": "Edit"|"Write", "tool_input": {file_path, ...}}
Behavior:
    - Read file from disk (old content). For new files (Write to non-existent),
      old content is empty.
    - Compute new content:
      * Edit: substring replacement (replace_all flag honoured)
      * Write: tool_input.content
    - Extract `### Human` section from old vs new (between `### Human` and
      next `### ` or `## ` heading).
    - Compare checkbox states (`[ ]` vs `[x]`) at matching positions.
    - If any position toggled and $CLAUDECODE=1: block exit 2.
    - Override: $FW_ALLOW_HUMAN_AC_TICK=1 allows + logs.
    - Without $CLAUDECODE: advisory log only (interactive human edits OK).

Exit codes:
    0 — allow (no Human section, no toggle, override active, or no CLAUDECODE)
    2 — block (CLAUDECODE=1 + Human-AC toggle + no override)

Performance: <50ms typical (Python startup dominates; logic is sub-ms).

Origin: T-1716 [REVIEW] checkbox ticked by agent on basis of verbal user
waiver. CLAUDE.md rule existed; no enforcement. T-1729 forensic.
"""
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


def extract_human_section(text: str) -> str:
    """Extract the `### Human` section: from `### Human` up to next `### ` or `## `."""
    if not text:
        return ""
    m = re.search(
        r"(?ms)^### Human\b.*?(?=^### |^## [^A]|\Z)",
        text,
    )
    return m.group(0) if m else ""


def get_checkbox_states(text: str) -> list[str]:
    """Return ordered list of checkbox states ('x' or ' ') in order of appearance."""
    return re.findall(r"^\s*-\s*\[([x ])\]", text, re.MULTILINE)


def detect_toggle(old_human: str, new_human: str) -> tuple[bool, list[tuple[int, str, str]]]:
    """
    Return (toggled, [(pos, old, new), ...]) for any checkbox state changes.

    Robust to line additions/removals: zips up to the shorter list. If all
    positions in old were preserved (same state) and only new ones added, no
    toggle. Toggles in matched positions are flagged.
    """
    old_boxes = get_checkbox_states(old_human)
    new_boxes = get_checkbox_states(new_human)
    toggles = []
    for i, (a, b) in enumerate(zip(old_boxes, new_boxes)):
        if a != b:
            toggles.append((i, a, b))
    return (bool(toggles), toggles)


def log_bypass(project_root: Path, task_id: str, file_path: str, toggles: list) -> None:
    """Append override usage to .context/working/.gate-bypass-log.yaml (existing T-1142 path)."""
    log_dir = project_root / ".context" / "working"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / ".gate-bypass-log.yaml"
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    toggle_summary = ", ".join(f"{i}:{a}->{b}" for i, a, b in toggles)
    # T-1861: double embedded single quotes for YAML single-quoted-scalar safety.
    def _q(v: str) -> str:
        return str(v).replace("'", "''")
    entry = (
        f"- timestamp: '{_q(ts)}'\n"
        f"  task: '{_q(task_id)}'\n"
        f"  flag: 'FW_ALLOW_HUMAN_AC_TICK'\n"
        f"  caller: 'check-human-ac-tick'\n"
        f"  file: '{_q(file_path)}'\n"
        f"  toggles: '{_q(toggle_summary)}'\n"
    )
    try:
        with log_file.open("a") as f:
            f.write(entry)
    except OSError:
        pass  # never block on telemetry


def derive_task_id(file_path: str) -> str:
    """Extract T-NNNN from a task file path."""
    m = re.search(r"T-\d+", file_path)
    return m.group(0) if m else "unknown"


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

    # Only inspect task files
    if "/.tasks/" not in file_path or not file_path.endswith(".md"):
        return 0

    project_root = Path(os.environ.get("PROJECT_ROOT", "."))

    # Read old content (file on disk before the edit)
    try:
        old_content = Path(file_path).read_text()
    except (FileNotFoundError, OSError):
        old_content = ""

    # Compute new content
    if tool_name == "Write":
        new_content = ti.get("content", "")
    elif tool_name == "Edit":
        old_str = ti.get("old_string", "")
        new_str = ti.get("new_string", "")
        replace_all = bool(ti.get("replace_all", False))
        if not old_str:
            return 0  # malformed Edit
        if replace_all:
            new_content = old_content.replace(old_str, new_str)
        else:
            new_content = old_content.replace(old_str, new_str, 1)
    elif tool_name == "MultiEdit":
        edits = ti.get("edits", [])
        new_content = old_content
        for edit in edits:
            o = edit.get("old_string", "")
            n = edit.get("new_string", "")
            if not o:
                continue
            if edit.get("replace_all", False):
                new_content = new_content.replace(o, n)
            else:
                new_content = new_content.replace(o, n, 1)
    else:
        return 0

    # Extract Human sections
    old_human = extract_human_section(old_content)
    new_human = extract_human_section(new_content)

    # If neither has a Human section, nothing to guard
    if not old_human and not new_human:
        return 0

    toggled, toggles = detect_toggle(old_human, new_human)
    if not toggled:
        return 0

    task_id = derive_task_id(file_path)

    # Override
    if os.environ.get("FW_ALLOW_HUMAN_AC_TICK") == "1":
        log_bypass(project_root, task_id, file_path, toggles)
        sys.stderr.write(
            f"NOTE: Human-AC tick allowed via FW_ALLOW_HUMAN_AC_TICK=1 — logged. "
            f"Task: {task_id}, toggles: {toggles}\n"
        )
        return 0

    # T-1739: multi-signal agent-control detection. CLAUDECODE alone proved
    # unreliable (T-1738 commit witnessed CLAUDECODE empty in PreToolUse env
    # despite shell having CLAUDECODE=1). Use either of: CLAUDECODE=1 or
    # AI_AGENT non-empty. We deliberately do NOT key on payload.tool_name
    # because tests legitimately supply tool JSON and would degrade to
    # blocking. See agents/context/check-active-task.sh:_under_agent_control
    # for the bash-side mirror.
    under_agent_control = (
        os.environ.get("CLAUDECODE") == "1"
        or bool(os.environ.get("AI_AGENT", "").strip())
    )

    # Block under agent control
    if under_agent_control:
        sys.stderr.write("\n")
        sys.stderr.write("══════════════════════════════════════════════════════════\n")
        sys.stderr.write("  HUMAN-AC TICK BLOCKED — Only the human may toggle\n")
        sys.stderr.write("══════════════════════════════════════════════════════════\n")
        sys.stderr.write("\n")
        sys.stderr.write(f"  Task:  {task_id}\n")
        sys.stderr.write(f"  File:  {file_path}\n")
        sys.stderr.write("\n")
        sys.stderr.write("  CLAUDE.md §Agent/Human AC Split:\n")
        sys.stderr.write("    'NEVER check a `### Human` AC. Only the human\n")
        sys.stderr.write("     may verify and check these boxes.'\n")
        sys.stderr.write("\n")
        sys.stderr.write("  Detected toggle(s) under `### Human`:\n")
        for i, a, b in toggles:
            sys.stderr.write(f"    position {i}: '[{a}]' → '[{b}]'\n")
        sys.stderr.write("\n")
        sys.stderr.write("  To proceed, choose ONE:\n")
        sys.stderr.write("\n")
        sys.stderr.write("    1. Hand to human via Watchtower (recommended):\n")
        sys.stderr.write(f"       fw task review {task_id}\n")
        sys.stderr.write("\n")
        sys.stderr.write("    2. Override with explicit env (logged Tier 2):\n")
        sys.stderr.write("       FW_ALLOW_HUMAN_AC_TICK=1 <retry your edit>\n")
        sys.stderr.write("\n")
        sys.stderr.write("  Policy: T-1731 (Human-AC Tick Guard, closes G2 from T-1729)\n")
        sys.stderr.write("══════════════════════════════════════════════════════════\n")
        sys.stderr.write("\n")
        return 2

    # No agent-control signal — advisory only (allow interactive human editing
    # in test/dev shell). Same multi-signal logic as the block branch but inverted.
    sys.stderr.write(
        f"NOTE: Human-AC checkbox toggle detected (advisory only — no agent-control "
        f"signal: CLAUDECODE/AI_AGENT/tool_name all empty). "
        f"Task: {task_id}, toggles: {toggles}\n"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
