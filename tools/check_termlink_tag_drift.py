#!/usr/bin/env python3
"""Scan live TermLink sessions for non-canonical tag prefixes.

This is the invariant-direct sibling of `agents/audit/orchestrator-mcp-scan.sh`'s
tag-format lint (T-1649) — same CANONICAL_PREFIXES set, same logic, but suitable
for use as a one-line P-011 verification command on tasks that touch tag-format
drift hygiene (T-1677 origin).

Exit 0 iff zero non-canonical prefixes are present across all live sessions.
Prints one line per drifted prefix (`prefix(count)` form) and exits 1 otherwise.

If the TermLink hub is unreachable, exits 0 with a warning to stderr — verification
should not fail merely because TermLink is offline. The audit lint will catch live
drift on its own daily cron.
"""
import json
import subprocess
import sys

# Mirrors agents/audit/orchestrator-mcp-scan.sh:101-104. Routing-relevant colon-
# separated prefixes + host metadata equals-separated prefixes are all canonical.
CANONICAL_PREFIXES = (
    "task-type:", "role:", "task:", "model:",
    "host=", "project=",
)


def _tag_prefix(tag: str) -> str | None:
    for sep in (":", "="):
        if sep in tag:
            return tag.split(sep, 1)[0] + sep
    return None


def main() -> int:
    try:
        out = subprocess.run(
            ["termlink", "list", "--json"],
            capture_output=True, text=True, timeout=10,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        print(f"WARN: termlink list unavailable ({e}); skipping drift check", file=sys.stderr)
        return 0
    if out.returncode != 0:
        print(f"WARN: termlink list exited {out.returncode}; skipping drift check", file=sys.stderr)
        return 0

    try:
        sessions = json.loads(out.stdout).get("sessions", []) or []
    except json.JSONDecodeError as e:
        print(f"WARN: termlink list JSON parse failed ({e}); skipping drift check", file=sys.stderr)
        return 0

    bad: dict[str, int] = {}
    for s in sessions:
        for tag in s.get("tags", []) or []:
            prefix = _tag_prefix(tag)
            if prefix is None or prefix in CANONICAL_PREFIXES:
                continue
            bad[prefix] = bad.get(prefix, 0) + 1

    if bad:
        for prefix, count in sorted(bad.items(), key=lambda x: (-x[1], x[0])):
            print(f"DRIFT {prefix}({count})")
        print(f"\n{sum(bad.values())} non-canonical tag(s) across {len(sessions)} session(s).")
        return 1
    print(f"OK: 0 non-canonical tags across {len(sessions)} live session(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
