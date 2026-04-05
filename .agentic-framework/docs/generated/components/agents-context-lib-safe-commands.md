# safe-commands

> Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/safe-commands.sh`

## What It Does

Safe-command allowlist for Bash task gate (T-650, T-630)
is_bash_safe_command() returns 0 if the command is read-only/diagnostic
and should be allowed without an active task.
Design evidence: 7920 Bash invocations analyzed from real session data.
Only 1.4% are file-writing operations. This allowlist catches the safe
98.6% for fast-path bypass.
Categories (27 patterns):
1. Git read-only (8 patterns)
2. File reading (7 patterns)
3. Searching (4 patterns)

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `agents/context/check-active-task.sh` | called_by |

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-safe-commands.yaml`*
*Last verified: 2026-03-28*
