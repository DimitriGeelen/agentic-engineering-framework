#!/usr/bin/env python3
"""T-1629 (B-3a of T-1626) — `fw doctor` active hook probe.

Reads $SETTINGS_FILE (.claude/settings.json), invokes every configured
Claude Code hook from /tmp (a stable foreign CWD that mimics agent
cd-drift), and reports any whose path doesn't resolve.

Output (machine-readable, parsed by bash):
  Line 1:    "<total>|<failures>"
  Lines 2+:  "FAIL|<event>|<short-tag>|<reason>"  (up to 5)

Hooks that exit 0 (clean) or 2 (intentional policy block) are treated
as healthy. Failure signals: rc==127, or stderr mentions "not found"
or "no such file" — the T-1626 witness shape (bare-relative
.agentic-framework/bin/fw paths that break under cd).

Why this is a separate file (L-332): in the hot-path hook dispatcher
(bin/fw), heredocs inside command substitution ($() subshells)
parse-error fragilely. A bin/fw parse error is unrecoverable from
inside Claude Code — every PreToolUse hook routes through bin/fw,
exit 2 = block. Lesson: keep Python helpers > ~10 lines as standalone
.py files and invoke as `python3 $FW_LIB_DIR/<helper>.py`.
"""
import json
import os
import subprocess
import sys


def _tag(cmd: str) -> str:
    """Short identifier for reporting: <binary>:<hook-subcmd> or <binary>."""
    parts = cmd.split()
    if not parts:
        return "?"
    name = parts[0].split("/")[-1]
    for i, p in enumerate(parts):
        if p == "hook" and i + 1 < len(parts):
            return f"{name}:{parts[i + 1]}"
    return name


def main() -> int:
    settings_file = os.environ.get("SETTINGS_FILE", "")
    if not settings_file:
        return 0
    try:
        with open(settings_file) as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        return 0

    # Scope to gate-style events. PreCompact / SessionStart legitimately
    # run heavy work (full handover, context resume) that exceeds the 5s
    # probe budget; their failure modes are different and out of scope
    # here. T-1626's witness was PreToolUse/PostToolUse — those fire on
    # every tool call and ARE the path-resolution failure surface.
    EXERCISE_EVENTS = {"PreToolUse", "PostToolUse"}

    fails = []
    total = 0
    for event, entries in data.get("hooks", {}).items():
        if event not in EXERCISE_EVENTS:
            continue
        for entry in entries:
            for hook in entry.get("hooks", []):
                cmd = hook.get("command", "")
                if not cmd:
                    continue
                total += 1
                try:
                    proc = subprocess.run(
                        ["/bin/sh", "-c", cmd],
                        input="{}",
                        capture_output=True,
                        text=True,
                        cwd="/tmp",
                        timeout=5,
                    )
                except subprocess.TimeoutExpired:
                    fails.append((event, _tag(cmd), "timeout"))
                    continue
                except Exception as e:
                    fails.append((event, _tag(cmd), f"spawn: {e}"))
                    continue
                rc = proc.returncode
                stderr_low = (proc.stderr or "").lower()
                if rc in (0, 2):
                    continue
                if (
                    rc == 127
                    or "not found" in stderr_low
                    or "no such file" in stderr_low
                ):
                    first_err = (
                        stderr_low.splitlines()[0]
                        if stderr_low
                        else f"exit {rc}, no stderr"
                    )
                    fails.append((event, _tag(cmd), f"exit {rc}: {first_err}"))

    print(f"{total}|{len(fails)}")
    for ev, tag, reason in fails[:5]:
        print(f"FAIL|{ev}|{tag}|{reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
