#!/usr/bin/env python3
"""T-2188: PreToolUse hook validating inception frontmatter schema.

Blocks Write/Edit on .tasks/{active,completed}/T-*.md when:
  - workflow_type: inception
  AND
  - target_blast_radius missing OR not int in 0..9
  - voi_score missing OR not float in 0..1

Bypass: FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1 (logged Tier-2 to .gate-bypass-log.yaml).
Producer/consumer parity per T-1890 — env-var is the universal bypass that
works through git commit and any external caller that rejects unknown flags.

Reads Claude Code hook JSON from stdin. Exit 0 = allow, exit 2 = block.
"""

from __future__ import annotations

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


PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", "/opt/999-Agentic-Engineering-Framework"))
TASK_FILE_RE = re.compile(r"\.tasks/(active|completed)/T-\d+-[^/]+\.md$")


def _read_frontmatter(path: Path) -> dict | None:
    """Parse YAML frontmatter (between leading ---/--- pair). Returns dict or None."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        return None
    yaml_block = text[4:end]
    # Minimal hand-parse — we only need top-level scalar keys, no nested structures.
    fm: dict = {}
    current_key = None
    for line in yaml_block.splitlines():
        if not line or line.startswith("#"):
            continue
        if line.startswith(" "):
            # Continuation / nested. We only care about top-level scalars here.
            continue
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*?)\s*$", line)
        if not m:
            continue
        key, val = m.group(1), m.group(2)
        # Strip trailing inline comment.
        if "#" in val and not (val.startswith('"') or val.startswith("'")):
            val = val.split("#", 1)[0].rstrip()
        fm[key] = val
        current_key = key
    return fm


def _validate(fm: dict) -> list[str]:
    """Return list of error messages, empty if valid."""
    errors: list[str] = []

    tbr = fm.get("target_blast_radius", "").strip()
    if tbr == "":
        errors.append("target_blast_radius missing (required int 0..9; see 050-Inceptions.md §Scoring Exception)")
    else:
        try:
            tbr_i = int(tbr)
            if not (0 <= tbr_i <= 9):
                errors.append(f"target_blast_radius={tbr_i} out of range (must be int 0..9)")
        except ValueError:
            errors.append(f"target_blast_radius={tbr!r} not an integer")

    voi = fm.get("voi_score", "").strip()
    if voi == "":
        errors.append("voi_score missing (required float 0..1; see 050-Inceptions.md §Scoring Exception)")
    else:
        try:
            voi_f = float(voi)
            if not (0.0 <= voi_f <= 1.0):
                errors.append(f"voi_score={voi_f} out of range (must be float 0..1)")
        except ValueError:
            errors.append(f"voi_score={voi!r} not a float")

    return errors


def _log_bypass(target: str, reason: str) -> None:
    """Append Tier-2 entry to .gate-bypass-log.yaml. Best-effort, never blocks."""
    log_path = PROJECT_ROOT / ".context" / "working" / ".gate-bypass-log.yaml"
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        entry = (
            f"- ts: '{ts}'\n"
            f"  gate: check-inception-schema\n"
            f"  target: {target}\n"
            f"  mechanism: FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1\n"
            f"  reason: {reason}\n"
        )
        with log_path.open("a", encoding="utf-8") as f:
            f.write(entry)
    except OSError:
        pass


def main() -> int:
    try:
        payload = json.load(sys.stdin)
        global PROJECT_ROOT  # T-2468: re-anchor to the worktree from stdin cwd
        PROJECT_ROOT = reanchor_project_root(payload, PROJECT_ROOT)
    except (json.JSONDecodeError, ValueError):
        return 0

    tool_input = payload.get("tool_input", {})
    file_path = tool_input.get("file_path") or tool_input.get("path") or ""
    if not file_path or not TASK_FILE_RE.search(file_path):
        return 0

    fp = Path(file_path)
    if not fp.is_absolute():
        fp = PROJECT_ROOT / fp

    # Read frontmatter (post-edit will be re-validated on next write if needed)
    fm = _read_frontmatter(fp)
    if fm is None:
        return 0  # No frontmatter — task creation or non-task file, let through

    if fm.get("workflow_type", "").strip() != "inception":
        return 0  # Not an inception, schema doesn't apply

    errors = _validate(fm)
    if not errors:
        return 0

    # Bypass check
    if os.environ.get("FW_ALLOW_INCEPTION_SCHEMA_DRIFT") == "1":
        _log_bypass(file_path, "; ".join(errors))
        print(
            f"NOTE: inception-schema drift override (FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1) — {file_path}",
            file=sys.stderr,
        )
        return 0

    msg = (
        "\n══════════════════════════════════════════════════════════\n"
        "  INCEPTION SCHEMA — required frontmatter fields missing\n"
        "══════════════════════════════════════════════════════════\n"
        f"\n  Target: {file_path}\n\n"
        "  Inception tasks must declare target_blast_radius (int 0..9)\n"
        "  and voi_score (float 0..1) so the BVP estimator can rank them\n"
        "  against build tasks. See 050-Inceptions.md §Scoring Exception.\n\n"
        "  Errors:\n"
    )
    for err in errors:
        msg += f"    - {err}\n"
    msg += (
        "\n  Add the fields to frontmatter, e.g.:\n"
        "    target_blast_radius: 3\n"
        "    voi_score: 0.5\n\n"
        "  Bypass (logged Tier-2):\n"
        "    FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1 <your command>\n\n"
        "  Policy: T-2188 (inception schema gate)\n"
        "  Bypass-mechanism contract: T-1890 (env-var path)\n"
        "══════════════════════════════════════════════════════════\n"
    )
    print(msg, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
