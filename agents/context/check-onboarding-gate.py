#!/usr/bin/env python3
"""
T-2815: refuse Write/Edit that adds an agent-unresolvable task to the gated
onboarding set (T-532's check-active-task.sh onboarding block).

The onboarding gate blocks all non-onboarding work until every active
`tags: [..., onboarding, ...]` task reaches `work-completed`. That exit
condition is only agent-reachable when the task's `owner` is `agent` (or
unset) AND the task does not require an action agents are structurally
forbidden to take:
  - `workflow_type: inception` — `fw inception decide` refuses under
    `$CLAUDECODE=1` (T-1259/T-1260); only a human can record the decision.
  - An unticked `### Human` acceptance-criteria subsection — agents must
    never tick a Human AC (CLAUDE.md §Agent/Human AC Split).

`owner: human` onboarding tasks are the sanctioned escape valve (excluded
from the gate's scan in check-active-task.sh) — this hook does NOT block
those. It blocks the complementary broken case: an onboarding task that
claims `owner: agent` (or leaves owner unset) but is still one of the two
agent-unresolvable shapes above. Left unblocked, that task would sit in the
gated set forever with no agent-reachable path to `work-completed` — the
exact deadlock T-2815 was filed to close.

Activation:
    PreToolUse Write|Edit|MultiEdit on .tasks/{active,completed}/T-*.md.
Receives stdin JSON from Claude Code:
    {"tool_name": ..., "tool_input": {file_path, content|old_string+new_string|edits}}

Exit codes:
    0 — allow (not a task file, not onboarding-tagged, owner:human, or
        agent-resolvable)
    2 — block (onboarding-tagged, owner != human, and agent-unresolvable,
        under agent control, no override)

Override:
    FW_ALLOW_ONBOARDING_UNRESOLVABLE=1 — bypass with Tier-2 log entry.

Origin: T-2815. Analogue: agents/context/check-inception-recommendation.py.
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

from lib.hook_paths import reanchor_project_root  # noqa: E402  (T-2468)

_TASK_RE = re.compile(r"/\.tasks/(active|completed)/T-\d+")
_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
_TAGS_RE = re.compile(r"^tags:\s*(.*?)\s*$", re.MULTILINE)
_OWNER_RE = re.compile(r"^owner:\s*(.*?)\s*$", re.MULTILINE)
_WORKFLOW_TYPE_RE = re.compile(r"^workflow_type:\s*(.*?)\s*$", re.MULTILINE)
_STATUS_RE = re.compile(r"^status:\s*(.*?)\s*$", re.MULTILINE)
# `### Human` AC subsection body: everything up to the next `###`/`##` heading.
_HUMAN_AC_RE = re.compile(
    r"^###\s*Human\s*$\n(.*?)(?=^###\s|^##\s|\Z)",
    re.DOTALL | re.MULTILINE,
)
_UNTICKED_AC_RE = re.compile(r"^\s*-\s*\[\s\]\s", re.MULTILINE)


def _derive_task_id(file_path: str) -> str:
    m = re.search(r"T-\d+", file_path)
    return m.group(0) if m else "unknown"


def _frontmatter(text: str) -> str:
    m = _FRONTMATTER_RE.search(text or "")
    return m.group(1) if m else ""


def _field(fm: str, pattern: re.Pattern) -> str:
    m = pattern.search(fm)
    if not m:
        return ""
    return m.group(1).strip().strip('"').strip("'")


def _parse_tags(raw: str) -> set:
    """Split a frontmatter tags value into its elements.

    Accepts the inline-list form (`[a, b]`, the template default) and the bare
    comma-separated form (`a, b`). Block-sequence form (`tags:` then `- a` on
    following lines) yields an empty value from _TAGS_RE and so returns empty —
    unchanged from the prior behaviour, which also could not see it.
    """
    return {
        t.strip().strip('"').strip("'")
        for t in raw.strip().lstrip("[").rstrip("]").split(",")
        if t.strip()
    }


def has_onboarding_tag(fm: str) -> bool:
    """True only when `onboarding` is a WHOLE tag, not a substring of one.

    T-2881: the previous form was `re.search(r"\\bonboarding\\b", tags)`, which
    matched inside `arc:onboarding-curriculum` — `:` and `-` are both non-word
    characters, so \\b sits happily on either side of the substring. Every task
    tagged into the onboarding-curriculum ARC was therefore read as a member of
    the gated onboarding SET: two different things that happen to share a word.

    It surfaced when arc-017's own Half A build task (T-2877, the human
    curriculum) was refused by arc-017's own Half B invariant for carrying an
    unticked `### Human` AC — correct behaviour applied to a task that was never
    in the gated set. The block was also unfixable in place: the documented
    override is an env-var prefix, and the refusal fires on the Write/Edit tool,
    which gives an agent no env surface to set it on.

    Tag membership is a list operation, so do it as one. A word-boundary regex
    over the raw `[a, b, c]` text cannot distinguish an element from a substring
    of an element, and no amount of tightening the boundaries fixes that — the
    structure has to be parsed, not pattern-matched.
    """
    return "onboarding" in _parse_tags(_field(fm, _TAGS_RE))


def is_agent_unresolvable(workflow_type: str, body: str) -> str | None:
    """Return a reason string if the task is agent-unresolvable, else None."""
    if workflow_type == "inception":
        return "inception-decide-blocked"
    m = _HUMAN_AC_RE.search(body or "")
    if m:
        human_section = re.sub(r"<!--.*?-->", "", m.group(1), flags=re.DOTALL)
        if _UNTICKED_AC_RE.search(human_section):
            return "human-ac-present"
    return None


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
        f"  flag: 'FW_ALLOW_ONBOARDING_UNRESOLVABLE'\n"
        f"  caller: 'check-onboarding-gate'\n"
        f"  file: '{_q(file_path)}'\n"
    )
    try:
        with log_file.open("a") as f:
            f.write(entry)
    except OSError:
        pass


def _emit_block(task_id: str, file_path: str, reason: str) -> None:
    reason_text = {
        "inception-decide-blocked": (
            "workflow_type: inception — fw inception decide refuses under\n"
            "  $CLAUDECODE=1 (T-1259/T-1260); only a human can record the decision."
        ),
        "human-ac-present": (
            "an unticked ### Human acceptance criterion exists — agents must\n"
            "  never tick a Human AC (CLAUDE.md §Agent/Human AC Split)."
        ),
    }.get(reason, reason)
    sys.stderr.write("\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("  ONBOARDING GATE DEADLOCK — T-2815 guard\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("\n")
    sys.stderr.write(f"  Task:    {task_id}\n")
    sys.stderr.write(f"  File:    {file_path}\n")
    sys.stderr.write(f"  Reason:  {reason}\n")
    sys.stderr.write("  Problem: task carries tags: [..., onboarding, ...] with\n")
    sys.stderr.write("           owner != human, but is agent-unresolvable:\n")
    sys.stderr.write(f"           {reason_text}\n")
    sys.stderr.write("\n")
    sys.stderr.write("  Left as-is, this task would sit in the gated onboarding set\n")
    sys.stderr.write("  forever — the T-532 gate (check-active-task.sh) blocks all\n")
    sys.stderr.write("  other work until every onboarding-tagged task not owned by\n")
    sys.stderr.write("  a human reaches work-completed, and no agent-reachable path\n")
    sys.stderr.write("  exists to do that here.\n")
    sys.stderr.write("\n")
    sys.stderr.write("  To proceed, choose ONE:\n")
    sys.stderr.write("\n")
    sys.stderr.write("    1. Set owner: human — the onboarding gate's scan (T-2815)\n")
    sys.stderr.write("       exempts owner:human tasks; the curriculum stays readable\n")
    sys.stderr.write("       and discoverable but never blocks agent work.\n")
    sys.stderr.write("\n")
    sys.stderr.write("    2. Remove the onboarding tag if this task should not be\n")
    sys.stderr.write("       part of the gated curriculum.\n")
    sys.stderr.write("\n")
    sys.stderr.write("    3. Override (logged Tier 2):\n")
    sys.stderr.write("         FW_ALLOW_ONBOARDING_UNRESOLVABLE=1 <command>\n")
    sys.stderr.write("\n")
    sys.stderr.write("  Origin: T-2815 (T-532 onboarding gate deadlocked on T-002).\n")
    sys.stderr.write("  See CLAUDE.md §Task System.\n")
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

    if not _TASK_RE.search(file_path):
        return 0
    if not file_path.endswith(".md"):
        return 0

    project_root = reanchor_project_root(data, os.environ.get("PROJECT_ROOT", "."))

    new_content = _compute_new_content(tool_name, ti, file_path)
    if new_content is None:
        return 0

    fm = _frontmatter(new_content)
    if not has_onboarding_tag(fm):
        return 0

    owner = _field(fm, _OWNER_RE).lower()
    if owner == "human":
        # Sanctioned escape valve — not this hook's concern.
        return 0

    status = _field(fm, _STATUS_RE).lower()
    if status == "work-completed":
        return 0

    workflow_type = _field(fm, _WORKFLOW_TYPE_RE).lower()
    reason = is_agent_unresolvable(workflow_type, new_content)
    if reason is None:
        return 0

    task_id = _derive_task_id(file_path)

    if os.environ.get("FW_ALLOW_ONBOARDING_UNRESOLVABLE") == "1":
        _log_bypass(project_root, task_id, file_path)
        sys.stderr.write(
            f"NOTE: onboarding task {task_id} is agent-unresolvable ({reason}) "
            f"but write allowed via FW_ALLOW_ONBOARDING_UNRESOLVABLE=1 — logged.\n"
        )
        return 0

    under_agent_control = (
        os.environ.get("CLAUDECODE") == "1"
        or bool(os.environ.get("AI_AGENT", "").strip())
    )
    if not under_agent_control:
        sys.stderr.write(
            f"NOTE: onboarding task {task_id} is agent-unresolvable ({reason}) — "
            f"would block under agent control.\n"
        )
        return 0

    _emit_block(task_id, file_path, reason)
    return 2


if __name__ == "__main__":
    sys.exit(main())
