#!/usr/bin/env python3
"""
T-1849: arc_id task-frontmatter validation hook (T-NEW-2).

Closes Q1 from the arc-grooming inception (T-1846): hostage state — a task
references an arc that does not exist. Predicated on D-Immutability (T-1848):
once an arc-NNN id is allocated, references stay valid forever. The slug form
is also accepted (filename stem). Empty/missing arc_id passes through —
unassigned tasks are allowed.

Activation:
    PreToolUse Write|Edit|MultiEdit on .tasks/{active,completed}/T-*.md.
Receives stdin JSON from Claude Code:
    {"tool_name": ..., "tool_input": {file_path, content|old_string+new_string|edits}}

Behavior:
    - Compute new content (Write: tool_input.content; Edit/MultiEdit: apply
      substitution to existing file content).
    - Parse YAML frontmatter; extract arc_id field.
    - If arc_id is empty/missing/null: pass through (exit 0).
    - If arc_id is non-empty:
        - Check `.context/arcs/<arc_id>.yaml` exists (slug form), OR
        - Scan `.context/arcs/*.yaml` for a file whose `id:` field == arc_id (arc-NNN form).
        - If neither: block exit 2 with actionable message.
    - Tier-2 override via env `FW_ALLOW_ARC_ID_DRIFT=1` (logged).

Exit codes:
    0 — allow (no arc_id, valid arc_id, override active, or not a task file)
    2 — block (arc_id set but does not resolve, under agent control, no override)

Performance: <50ms typical. Mirrors check-human-ac-tick.py:main shape.
"""
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# T-2468: resolve lib/ to import the shared hook project-root resolver
# (parity with lib/paths.sh:fw_reanchor_from_cwd — re-anchor to the worktree).
_FW_T2468 = Path(__file__).resolve().parent.parent.parent
if str(_FW_T2468) not in sys.path:
    sys.path.insert(0, str(_FW_T2468))
from lib.hook_paths import reanchor_project_root  # noqa: E402


_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
_ARC_ID_RE = re.compile(r"^arc_id:\s*(.*?)\s*$", re.MULTILINE)
# Match `id: arc-NNN` (or `id: <slug>`) inside arc YAMLs.
_ARC_YAML_ID_RE = re.compile(r"^id:\s*([A-Za-z0-9_-]+)\s*$", re.MULTILINE)


def extract_arc_id(text: str) -> str | None:
    """Return the arc_id value from frontmatter, or None if missing/empty/null."""
    if not text:
        return None
    fm_match = _FRONTMATTER_RE.search(text)
    if not fm_match:
        return None
    arc_match = _ARC_ID_RE.search(fm_match.group(1))
    if not arc_match:
        return None
    val = arc_match.group(1).strip().strip('"').strip("'")
    # Treat empty, null, '~', commented-out as "not set"
    if not val or val.lower() in ("null", "~", "none"):
        return None
    return val


def resolve_arc_id(project_root: Path, arc_id: str) -> bool:
    """Return True if arc_id resolves to an arc YAML (slug filename OR arc-NNN id)."""
    arcs_dir = project_root / ".context" / "arcs"
    if not arcs_dir.is_dir():
        return False

    # Slug-form: direct filename lookup (cheap path).
    if (arcs_dir / f"{arc_id}.yaml").is_file():
        return True

    # arc-NNN form: scan for matching `id:` field. Only worth scanning when
    # input matches the arc-NNN pattern — otherwise it's a slug that just
    # doesn't exist.
    if re.match(r"^arc-\d+$", arc_id):
        for af in arcs_dir.glob("*.yaml"):
            try:
                text = af.read_text()
            except OSError:
                continue
            m = _ARC_YAML_ID_RE.search(text)
            if m and m.group(1) == arc_id:
                return True
    return False


def derive_task_id(file_path: str) -> str:
    """Extract T-NNNN from a task file path."""
    m = re.search(r"T-\d+", file_path)
    return m.group(0) if m else "unknown"


def log_bypass(project_root: Path, task_id: str, file_path: str, arc_id: str) -> None:
    """Append override usage to .context/working/.gate-bypass-log.yaml (T-1142 path)."""
    log_dir = project_root / ".context" / "working"
    try:
        log_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        return  # never block on telemetry
    log_file = log_dir / ".gate-bypass-log.yaml"
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    # L-392: double embedded single quotes for YAML single-quoted-scalar safety.
    def _q(v: str) -> str:
        return str(v).replace("'", "''")
    entry = (
        f"- timestamp: '{_q(ts)}'\n"
        f"  task: '{_q(task_id)}'\n"
        f"  flag: 'FW_ALLOW_ARC_ID_DRIFT'\n"
        f"  caller: 'check-arc-id'\n"
        f"  file: '{_q(file_path)}'\n"
        f"  arc_id: '{_q(arc_id)}'\n"
    )
    try:
        with log_file.open("a") as f:
            f.write(entry)
    except OSError:
        pass


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

    # Only inspect task files in .tasks/{active,completed}/T-XXX-*.md
    if not re.search(r"/\.tasks/(active|completed)/T-\d+", file_path):
        return 0
    if not file_path.endswith(".md"):
        return 0

    project_root = reanchor_project_root(data, os.environ.get("PROJECT_ROOT", "."))

    # Read existing content (empty for new file).
    try:
        old_content = Path(file_path).read_text()
    except (FileNotFoundError, OSError):
        old_content = ""

    # Compute new content.
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

    new_arc_id = extract_arc_id(new_content)
    if new_arc_id is None:
        # Unassigned tasks always allowed.
        return 0

    # If old already had this exact arc_id and it didn't validate then, the
    # current write isn't making things worse — but framework rule says any
    # WRITE that puts a non-resolving arc_id into a task file fails. (No
    # grandfather clause: agents shouldn't intentionally introduce stale refs.)
    if resolve_arc_id(project_root, new_arc_id):
        return 0

    task_id = derive_task_id(file_path)

    # Override
    if os.environ.get("FW_ALLOW_ARC_ID_DRIFT") == "1":
        log_bypass(project_root, task_id, file_path, new_arc_id)
        sys.stderr.write(
            f"NOTE: arc_id '{new_arc_id}' did not resolve, but write was allowed "
            f"via FW_ALLOW_ARC_ID_DRIFT=1 — logged. Task: {task_id}\n"
        )
        return 0

    # T-1739 detection mirror: agent control = CLAUDECODE=1 OR AI_AGENT non-empty.
    under_agent_control = (
        os.environ.get("CLAUDECODE") == "1"
        or bool(os.environ.get("AI_AGENT", "").strip())
    )

    if not under_agent_control:
        # Interactive human edits — advisory only.
        sys.stderr.write(
            f"NOTE: arc_id '{new_arc_id}' in {task_id} does not resolve to any "
            f".context/arcs/*.yaml — would block under agent control.\n"
        )
        return 0

    arcs_dir = project_root / ".context" / "arcs"
    available = sorted(p.stem for p in arcs_dir.glob("*.yaml")) if arcs_dir.is_dir() else []

    sys.stderr.write("\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("  ARC_ID DOES NOT RESOLVE — Hostage-state guard (T-1849)\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("\n")
    sys.stderr.write(f"  Task:    {task_id}\n")
    sys.stderr.write(f"  File:    {file_path}\n")
    sys.stderr.write(f"  arc_id:  '{new_arc_id}'\n")
    sys.stderr.write("\n")
    sys.stderr.write("  arc_id must resolve to one of:\n")
    sys.stderr.write("    - filename stem (slug):  .context/arcs/<arc_id>.yaml\n")
    sys.stderr.write("    - allocated numeric id:  .context/arcs/*.yaml with `id: arc-NNN`\n")
    sys.stderr.write("\n")
    if available:
        sys.stderr.write("  Available arcs (slug form):\n")
        for slug in available:
            sys.stderr.write(f"    - {slug}\n")
        sys.stderr.write("\n")
    sys.stderr.write("  To proceed, choose ONE:\n")
    sys.stderr.write("    1. Correct arc_id to a valid slug or arc-NNN form, OR\n")
    sys.stderr.write("    2. Remove the arc_id field (unassigned tasks are allowed), OR\n")
    sys.stderr.write("    3. Override (logged Tier 2):  FW_ALLOW_ARC_ID_DRIFT=1 ...\n")
    sys.stderr.write("\n")
    sys.stderr.write("  Origin: arc-grooming inception Q1 (T-1846); D-Immutability (T-1848).\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    return 2


if __name__ == "__main__":
    sys.exit(main())
