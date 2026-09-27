#!/usr/bin/env python3
"""T-1945 — Heredoc-in-cmd-substitution detector helper.

Reads a PreToolUse JSON payload on stdin and prints three lines:

    Line 1: tool_name (Write|Edit|other)
    Line 2: file_path
    Line 3: "MATCH" if the proposed `new_string` (Edit) or `content` (Write)
            contains the L-332/L-408 anti-pattern, else "OK"

Bash callers consume the three lines with `mapfile` or `read` and emit
the warning when line 3 == "MATCH" and (file_path ends with /bin/fw OR
file_path == bin/fw).

Extracted from the hook script per L-332 / L-408: the previous inline
`read ... <<< $(echo $INPUT | python3 - <<'PY' ... PY)` shape had
python3 consuming the heredoc as stdin instead of the pipe content,
so json.load always failed silently and the guard misfired.

Anti-patterns matched:
  1. `$(... python3 - ... <<TAG`        — the exact T-1942 shape
  2. `$(... <<['"]?[A-Z_][A-Z_0-9]*`    — any heredoc-in-cmd-sub
"""
import json
import re
import sys


PATTERN_1 = re.compile(r"\$\([^)]*python3[^)]*<<")
PATTERN_2 = re.compile(r"""\$\([^)]*<<['"]?[A-Z_][A-Z_0-9]*""")


def main() -> int:
    try:
        d = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        print("UNKNOWN")
        print("")
        print("OK")
        return 0
    tool = d.get("tool_name", "") or ""
    ti = d.get("tool_input", {}) or {}
    fp = ti.get("file_path", "") or ""
    payload = ti.get("new_string") or ti.get("content") or ""
    matched = bool(PATTERN_1.search(payload) or PATTERN_2.search(payload))
    print(tool)
    print(fp)
    print("MATCH" if matched else "OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
