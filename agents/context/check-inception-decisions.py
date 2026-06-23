#!/usr/bin/env python3
"""
T-1984: inception_decisions task-frontmatter validation hook.

Closes G-066 structural prevention: inception Decisions become machine-readable;
build children declare unlocks_inception_decision; hook blocks writes that
introduce malformed or unresolvable entries.

Activation:
    PreToolUse Write|Edit|MultiEdit on .tasks/{active,completed}/T-*.md.
Receives stdin JSON from Claude Code:
    {"tool_name": ..., "tool_input": {file_path, content|old_string+new_string|edits}}

Behavior (inception tasks — workflow_type: inception or inception_decisions: present):
    - Compute new content (Write/Edit/MultiEdit).
    - Parse inception_decisions: from YAML frontmatter.
    - If empty/missing: pass through (exit 0).
    - If non-empty: validate each entry (shape, id uniqueness, text present).
      Structural errors → block (exit 2).
    - Reachability (ships_in referent) NOT checked at write time — that is the
      close gate in update-task.sh. Hook only checks syntax and structure.

Behavior (build tasks — workflow_type: build or unlocks_inception_decision: present):
    - Parse unlocks_inception_decision: from YAML frontmatter.
    - If non-empty: validate each T-XXX:decision-id reference against the
      referenced inception task's inception_decisions: entries.
    - Invalid reference → block (exit 2).

Exit codes:
    0 — allow
    2 — block (structural error, under agent control, no override)

Override:
    FW_ALLOW_INCEPTION_DECISIONS_DRIFT=1 — bypass with Tier-2 log entry.

Origin: T-1983 GO; T-1984 build. Analogue: agents/context/check-arc-id.py (T-1849).
"""
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# Resolve lib/ relative to this script (works whether run directly or via fw hook)
_SCRIPT_DIR = Path(__file__).resolve().parent
_FRAMEWORK_ROOT = _SCRIPT_DIR.parent.parent
if str(_FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(_FRAMEWORK_ROOT))

from lib.hook_paths import reanchor_project_root  # noqa: E402  (T-2468)
from lib.inception_decisions import (  # noqa: E402
    parse_inception_decisions,
    parse_unlocks_field,
    validate_unlocks_references,
)

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
        f"  flag: 'FW_ALLOW_INCEPTION_DECISIONS_DRIFT'\n"
        f"  caller: 'check-inception-decisions'\n"
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

    new_content = _compute_new_content(tool_name, ti, file_path)
    if new_content is None:
        return 0

    task_id = _derive_task_id(file_path)
    override_active = os.environ.get("FW_ALLOW_INCEPTION_DECISIONS_DRIFT") == "1"

    # --- Check inception_decisions: field ---
    id_result = parse_inception_decisions(new_content)
    if id_result.errors:
        if override_active:
            _log_bypass(project_root, task_id, file_path)
            sys.stderr.write(
                f"NOTE: inception_decisions in {task_id} has structural errors but "
                f"write allowed via FW_ALLOW_INCEPTION_DECISIONS_DRIFT=1 — logged.\n"
            )
            return 0

        under_agent = (
            os.environ.get("CLAUDECODE") == "1"
            or bool(os.environ.get("AI_AGENT", "").strip())
        )
        if not under_agent:
            sys.stderr.write(
                f"NOTE: inception_decisions in {task_id} has structural errors "
                f"(would block under agent control): {'; '.join(id_result.errors)}\n"
            )
            return 0

        _emit_inception_decisions_block(task_id, file_path, id_result.errors)
        return 2

    # --- Check unlocks_inception_decision: field ---
    entries, unlock_errors = parse_unlocks_field(new_content)
    if unlock_errors:
        if override_active:
            _log_bypass(project_root, task_id, file_path)
            sys.stderr.write(
                f"NOTE: unlocks_inception_decision in {task_id} has errors but "
                f"write allowed via FW_ALLOW_INCEPTION_DECISIONS_DRIFT=1 — logged.\n"
            )
            return 0

        under_agent = (
            os.environ.get("CLAUDECODE") == "1"
            or bool(os.environ.get("AI_AGENT", "").strip())
        )
        if not under_agent:
            sys.stderr.write(
                f"NOTE: unlocks_inception_decision in {task_id} has errors "
                f"(would block under agent control): {'; '.join(unlock_errors)}\n"
            )
            return 0

        _emit_unlocks_block(task_id, file_path, unlock_errors)
        return 2

    # Validate unlocks references against their inception tasks
    if entries:
        ref_errors = validate_unlocks_references(entries, project_root)
        if ref_errors:
            if override_active:
                _log_bypass(project_root, task_id, file_path)
                sys.stderr.write(
                    f"NOTE: unlocks_inception_decision references in {task_id} invalid but "
                    f"write allowed via FW_ALLOW_INCEPTION_DECISIONS_DRIFT=1 — logged.\n"
                )
                return 0

            under_agent = (
                os.environ.get("CLAUDECODE") == "1"
                or bool(os.environ.get("AI_AGENT", "").strip())
            )
            if not under_agent:
                sys.stderr.write(
                    f"NOTE: unlocks_inception_decision references in {task_id} are invalid "
                    f"(would block under agent control): {'; '.join(ref_errors)}\n"
                )
                return 0

            _emit_unlocks_block(task_id, file_path, ref_errors)
            return 2

    return 0


def _emit_inception_decisions_block(
    task_id: str, file_path: str, errors: list[str]
) -> None:
    sys.stderr.write("\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("  INCEPTION_DECISIONS STRUCTURAL ERROR — T-1984 guard\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("\n")
    sys.stderr.write(f"  Task:  {task_id}\n")
    sys.stderr.write(f"  File:  {file_path}\n")
    sys.stderr.write("\n")
    sys.stderr.write("  Errors found in inception_decisions: field:\n")
    for err in errors:
        sys.stderr.write(f"    - {err}\n")
    sys.stderr.write("\n")
    sys.stderr.write("  Each entry must be: {id: kebab-slug, text: one-liner, ships_in: <ref>}\n")
    sys.stderr.write("  ships_in shapes: path/to/file, module.func, path::test, T-XXX, deferred:T-YYY\n")
    sys.stderr.write("\n")
    sys.stderr.write("  To override (Tier-2 logged): FW_ALLOW_INCEPTION_DECISIONS_DRIFT=1\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")


def _emit_unlocks_block(
    task_id: str, file_path: str, errors: list[str]
) -> None:
    sys.stderr.write("\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("  UNLOCKS_INCEPTION_DECISION ERROR — T-1984 guard\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("\n")
    sys.stderr.write(f"  Task:  {task_id}\n")
    sys.stderr.write(f"  File:  {file_path}\n")
    sys.stderr.write("\n")
    sys.stderr.write("  Errors in unlocks_inception_decision: field:\n")
    for err in errors:
        sys.stderr.write(f"    - {err}\n")
    sys.stderr.write("\n")
    sys.stderr.write("  Each entry must be: T-XXX:decision-id\n")
    sys.stderr.write("  Referenced inception task must exist and have that decision id\n")
    sys.stderr.write("  in its inception_decisions: list.\n")
    sys.stderr.write("\n")
    sys.stderr.write("  To override (Tier-2 logged): FW_ALLOW_INCEPTION_DECISIONS_DRIFT=1\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")


if __name__ == "__main__":
    sys.exit(main())
