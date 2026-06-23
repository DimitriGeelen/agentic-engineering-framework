#!/usr/bin/env python3
"""
T-2205 (T-2204 Slice B): PreToolUse Write/Edit hook — refuse save when an
inception task has a template-only `## Recommendation` block under
$CLAUDECODE=1.

Closes one leaf of the L-399 producer/consumer parity gap left by T-1716:
T-1716's `--recommendation` requirement fires on `fw inception start` only.
Agents can bypass by Write/Edit-ing a `.tasks/{active,completed}/T-*.md`
file with `workflow_type: inception` in frontmatter and an empty
`## Recommendation` block (template comment only) — no gate stops them,
and `fw task review` / `fw task review-batch` happily emit the
`/inception/<id>` handoff URL for an inception with no advisory.

This hook closes the Write/Edit producer leaf. Siblings (T-2204 GO scope):
  - CLI-side leaf: `fw task create --type inception` + `fw work-on
    --type inception` should mirror the T-1716 requirement.
  - Consumer-side leaf: `fw task review` / `fw task review-batch`
    should refuse emission when Recommendation block is template-only.

Activation:
    PreToolUse Write|Edit|MultiEdit on .tasks/{active,completed}/T-*.md.
Receives stdin JSON from Claude Code:
    {"tool_name": ..., "tool_input": {file_path, content|old_string+new_string|edits}}

Behavior:
    1. Compute new content (Write: tool_input.content; Edit/MultiEdit:
       apply substitution to existing file content).
    2. Parse YAML frontmatter; if workflow_type != 'inception', pass through.
    3. Inspect the `## Recommendation` body. If it contains a non-template
       `**Recommendation:** GO|NO-GO|DEFER` line, pass through.
    4. If under agent control ($CLAUDECODE=1 or $AI_AGENT non-empty) AND
       block is template-only:
         - If FW_ALLOW_EMPTY_RECOMMENDATION=1: log Tier-2 bypass + pass.
         - Else: exit 2 with block message naming both bypass mechanisms.
    5. If not under agent control: advisory NOTE on stderr, return 0.

Exit codes:
    0 — pass (not an inception, populated Recommendation, override active,
        not under agent control, or not a task file).
    2 — block (inception with template-only Recommendation under agent control).

Performance: <50ms typical. Mirrors check-arc-id.py and
check-inception-decisions.py.
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
_WORKFLOW_TYPE_RE = re.compile(r"^workflow_type:\s*(.*?)\s*$", re.MULTILINE)
# Match the `**Recommendation:**` line under the `## Recommendation` heading.
# Body content is everything from `## Recommendation` to the next `## ` heading
# (or EOF if Recommendation is the last section).
_REC_HEADING_RE = re.compile(
    r"^## Recommendation\s*\n(.*?)(?=^## |\Z)",
    re.DOTALL | re.MULTILINE,
)
# A populated Recommendation block contains a `Recommendation:` line with
# a verdict. `**` (bold) is stripped before matching so `**Recommendation:**`,
# `Recommendation:`, and `**Recommendation**:` all parse identically
# (T-1580 extractor parity).
_REC_VERDICT_RE = re.compile(
    r"^\s*Recommendation:\s*(GO|NO[- ]?GO|DEFER)\b",
    re.MULTILINE | re.IGNORECASE,
)


def extract_workflow_type(text: str) -> str | None:
    """Return workflow_type from frontmatter, lowercased; None if missing/empty."""
    if not text:
        return None
    fm_match = _FRONTMATTER_RE.search(text)
    if not fm_match:
        return None
    wt_match = _WORKFLOW_TYPE_RE.search(fm_match.group(1))
    if not wt_match:
        return None
    val = wt_match.group(1).strip().strip('"').strip("'").lower()
    if not val or val in ("null", "~", "none"):
        return None
    return val


def has_populated_recommendation(text: str) -> bool:
    """True iff `## Recommendation` body contains a real verdict line.

    Template-only blocks (HTML comment, empty body) return False.
    A `**Recommendation:** GO|NO-GO|DEFER` line returns True.
    """
    if not text:
        return False
    heading_match = _REC_HEADING_RE.search(text)
    if not heading_match:
        # No `## Recommendation` heading at all — treat as unpopulated.
        return False
    body = heading_match.group(1)
    # Strip HTML comments so the verdict-detector ignores the template stub.
    body_no_comments = re.sub(r"<!--.*?-->", "", body, flags=re.DOTALL)
    # Strip `**` (bold markers) so `**Recommendation:**`, `Recommendation:`,
    # and `**Recommendation**:` all match the same simple verdict pattern.
    body_normalized = body_no_comments.replace("**", "")
    return bool(_REC_VERDICT_RE.search(body_normalized))


def derive_task_id(file_path: str) -> str:
    """Extract T-NNNN from a task file path."""
    m = re.search(r"T-\d+", file_path)
    return m.group(0) if m else "unknown"


def log_bypass(project_root: Path, task_id: str, file_path: str) -> None:
    """Append override usage to .context/working/.gate-bypass-log.yaml."""
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
        f"  flag: 'FW_ALLOW_EMPTY_RECOMMENDATION'\n"
        f"  caller: 'check-inception-recommendation'\n"
        f"  file: '{_q(file_path)}'\n"
        f"  reason: 'empty-recommendation bypass'\n"
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

    workflow_type = extract_workflow_type(new_content)
    if workflow_type != "inception":
        # Not an inception — this hook is silent. (Other gates may fire.)
        return 0

    if has_populated_recommendation(new_content):
        # Populated — pass.
        return 0

    task_id = derive_task_id(file_path)

    # T-1739 detection mirror: agent control = CLAUDECODE=1 OR AI_AGENT non-empty.
    under_agent_control = (
        os.environ.get("CLAUDECODE") == "1"
        or bool(os.environ.get("AI_AGENT", "").strip())
    )

    # Override
    if os.environ.get("FW_ALLOW_EMPTY_RECOMMENDATION") == "1":
        log_bypass(project_root, task_id, file_path)
        sys.stderr.write(
            f"NOTE: inception {task_id} has template-only ## Recommendation, "
            f"but write was allowed via FW_ALLOW_EMPTY_RECOMMENDATION=1 — logged.\n"
        )
        return 0

    if not under_agent_control:
        # Interactive human edits — advisory only.
        sys.stderr.write(
            f"NOTE: inception {task_id} has template-only ## Recommendation — "
            f"would block under agent control.\n"
        )
        return 0

    sys.stderr.write("\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("  INCEPTION RECOMMENDATION MISSING — T-2204/T-2205 gate\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    sys.stderr.write("\n")
    sys.stderr.write(f"  Task:    {task_id}\n")
    sys.stderr.write(f"  File:    {file_path}\n")
    sys.stderr.write("  Status:  workflow_type: inception, ## Recommendation block\n")
    sys.stderr.write("           is empty or template-only (no GO|NO-GO|DEFER verdict).\n")
    sys.stderr.write("\n")
    sys.stderr.write("  The framework's §'Presenting Work for Human Review' (T-679)\n")
    sys.stderr.write("  rule: the agent always writes the advisory before the human\n")
    sys.stderr.write("  sees the page. T-1716 enforced this on `fw inception start`;\n")
    sys.stderr.write("  this hook (T-2205) closes the Write/Edit producer leaf.\n")
    sys.stderr.write("\n")
    sys.stderr.write("  To proceed, choose ONE:\n")
    sys.stderr.write("\n")
    sys.stderr.write("    1. Canonical filing path — re-file via:\n")
    sys.stderr.write("         bin/fw inception start \"<name>\" \\\n")
    sys.stderr.write("             --recommendation GO|NO-GO|DEFER \\\n")
    sys.stderr.write("             --rationale '<reason>'\n")
    sys.stderr.write("       (the inception body is generated with Recommendation populated)\n")
    sys.stderr.write("\n")
    sys.stderr.write("    2. Add the Recommendation block to this file as part of\n")
    sys.stderr.write("       your current edit. Required shape:\n")
    sys.stderr.write("         ## Recommendation\n")
    sys.stderr.write("         **Recommendation:** GO | NO-GO | DEFER\n")
    sys.stderr.write("         **Rationale:** <evidence-cited reasoning>\n")
    sys.stderr.write("\n")
    sys.stderr.write("    3. Override (logged Tier 2):\n")
    sys.stderr.write("         FW_ALLOW_EMPTY_RECOMMENDATION=1 <command>\n")
    sys.stderr.write("       (use only when you genuinely cannot yet write a\n")
    sys.stderr.write("        recommendation — e.g. mid-exploration scratch edit)\n")
    sys.stderr.write("\n")
    sys.stderr.write("  Bypass mechanism note (T-1890 producer/consumer parity):\n")
    sys.stderr.write("    Write/Edit tool calls accept env var override only.\n")
    sys.stderr.write("    Fw verbs (when this gate ships there) will also accept\n")
    sys.stderr.write("    `--allow-empty-recommendation` flag.\n")
    sys.stderr.write("\n")
    sys.stderr.write("  Origin: T-679 (rule), T-1715/T-1716 (filing-time gate on\n")
    sys.stderr.write("  fw inception start), T-2204 (bypass-paths inception),\n")
    sys.stderr.write("  T-2205 (this hook). See CLAUDE.md §Presenting Work for\n")
    sys.stderr.write("  Human Review.\n")
    sys.stderr.write("══════════════════════════════════════════════════════════\n")
    return 2


if __name__ == "__main__":
    sys.exit(main())
