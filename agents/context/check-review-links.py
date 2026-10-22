#!/usr/bin/env python3
"""
T-4624 (G-123): review-link allowlist at task-file write time.

The operator reads `### Human` Steps/Expected/If-not and `## Recommendation` on
/review/<id>. Every page reference there must be a literal http(s):// URL. A
`$(… bin/fw watchtower url)/path`, any `fw watchtower url` mention, or a bare
`/route` reached the operator five times because the only check ran at
`fw task review`, after the task was written and often after it was flipped.

Activation:
    PreToolUse Write|Edit|MultiEdit on .tasks/active/T-*.md.

Behavior:
    - Compute the new content (same shape as check-arc-id.py).
    - Run lib/review_link_validator.detect_homework_patterns on old and new.
    - Block (exit 2) only on findings the write INTRODUCES. A task that already
      carries a bad link stays editable (ticking an Agent AC must not be held
      hostage); `fw task review` and the partial-complete gate still catch it.
    - Override: env FW_ALLOW_REVIEW_LINK_HOMEWORK=1 on the session (logged Tier-2).

Exit codes: 0 allow, 2 block.
"""
import json
import os
import re
import sys
from pathlib import Path

_FW = Path(__file__).resolve().parent.parent.parent
if str(_FW) not in sys.path:
    sys.path.insert(0, str(_FW))
if str(_FW / "lib") not in sys.path:
    sys.path.insert(0, str(_FW / "lib"))

import review_link_validator as V  # noqa: E402


def _new_content(tool_name: str, ti: dict, old: str):
    if tool_name == "Write":
        return ti.get("content", "")
    if tool_name == "Edit":
        o, n = ti.get("old_string", ""), ti.get("new_string", "")
        if not o:
            return None
        return old.replace(o, n) if ti.get("replace_all") else old.replace(o, n, 1)
    if tool_name == "MultiEdit":
        out = old
        for e in ti.get("edits", []) or []:
            o, n = e.get("old_string", ""), e.get("new_string", "")
            if not o:
                continue
            out = out.replace(o, n) if e.get("replace_all") else out.replace(o, n, 1)
        return out
    return None


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0  # malformed input — fail open
    tool_name = data.get("tool_name", "")
    if tool_name not in ("Write", "Edit", "MultiEdit"):
        return 0
    ti = data.get("tool_input", {}) or {}
    file_path = ti.get("file_path") or ""
    if not re.search(r"(^|/)\.tasks/active/T-\d+[^/]*\.md$", file_path):
        return 0

    try:
        old = Path(file_path).read_text(encoding="utf-8")
    except OSError:
        old = ""
    new = _new_content(tool_name, ti, old)
    if new is None:
        return 0

    try:
        before = {m for _, m in V.detect_homework_patterns(old)} if old else set()
        after = [m for lvl, m in V.detect_homework_patterns(new) if lvl == "block"]
    except Exception:
        return 0  # a validator bug must never block every task write
    introduced = [m for m in after if m not in before]
    if not introduced:
        return 0

    if os.environ.get("FW_ALLOW_REVIEW_LINK_HOMEWORK") == "1":
        V._log_tier2_bypass(file_path, "FW_ALLOW_REVIEW_LINK_HOMEWORK=1 (check-review-links hook)")
        return 0

    from lib.hook_paths import reanchor_project_root
    root = reanchor_project_root(data, os.environ.get("PROJECT_ROOT", "."))
    try:
        base = (root / ".context" / "working" / "watchtower.url").read_text().strip()
    except OSError:
        base = ""
    base = base.rstrip("/") or "http://<host>:<port>"
    tid = V._task_id_from_path(file_path)
    print("BLOCKED: review links must be literal full URLs (T-4624, G-123)", file=sys.stderr)
    print("", file=sys.stderr)
    print("  In ### Human Steps/Expected/If-not and ## Recommendation the operator", file=sys.stderr)
    print("  clicks what you write. This write introduces:", file=sys.stderr)
    for m in introduced:
        print(f"    - {m}", file=sys.stderr)
    print("", file=sys.stderr)
    print(f"  Write the literal URL instead, e.g. {base}/review/{tid}", file=sys.stderr)
    print("  `$(bin/fw watchtower url)` belongs only in ## Verification (machine-run).", file=sys.stderr)
    print("  Override (operator, logged Tier 2): FW_ALLOW_REVIEW_LINK_HOMEWORK=1 on the session.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
