#!/usr/bin/env python3
"""T-1629 (B-3a of T-1626) & T-070 — `fw doctor` active hook probe.

Reads $SETTINGS_FILE (.claude/settings.json or .agents/hooks.json), invokes
every configured hook, and reports any whose path doesn't resolve.
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
        if "bridge" in name and i + 1 < len(parts):
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

    project_dir = os.path.dirname(os.path.dirname(os.path.abspath(settings_file)))
    probe_env = dict(os.environ, CLAUDE_PROJECT_DIR=project_dir, PROJECT_ROOT=project_dir)

    EXERCISE_EVENTS = {"PreToolUse", "PostToolUse"}

    fails = []
    total = 0

    # Handle Claude Code settings.json format vs Antigravity hooks.json format
    hook_groups = []
    if "hooks" in data and isinstance(data["hooks"], dict):
        hook_groups.append(("", data["hooks"]))
    else:
        # Antigravity dictionary of group names
        for group_name, group_val in data.items():
            if isinstance(group_val, dict):
                hook_groups.append((group_name, group_val))

    for group_name, events_dict in hook_groups:
        for event, entries in events_dict.items():
            if event not in EXERCISE_EVENTS:
                continue
            if not isinstance(entries, list):
                continue
            for entry in entries:
                for hook in entry.get("hooks", []):
                    cmd = hook.get("command", "")
                    if not cmd:
                        continue
                    total += 1
                    test_cwd = os.path.join(project_dir, ".agents") if os.path.basename(settings_file) == "hooks.json" else "/tmp"
                    if not os.path.exists(test_cwd):
                        test_cwd = "/tmp"
                    try:
                        proc = subprocess.run(
                            ["/bin/sh", "-c", cmd],
                            input="{}",
                            capture_output=True,
                            text=True,
                            cwd=test_cwd,
                            env=probe_env,
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
