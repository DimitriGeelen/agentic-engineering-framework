# session_start_hook_warning

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/session_start_hook_warning.bats`

## What It Does

T-1630 (B-4 of T-1626) — SessionStart resume hook warns on broken hooks.
When `agents/context/post-compact-resume.sh` fires (SessionStart:compact /
SessionStart:resume), it probes every PreToolUse/PostToolUse hook from /tmp
(via `lib/doctor-hook-exercise.py`, shared with B-3a / T-1629) and appends
a warning section to the additionalContext JSON if any hooks fail to
resolve. This makes the T-1626 witness scenario surface in the agent's
session-start context — not just on a manual `fw doctor`.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | calls | Session Resume Hook — Reinject structured context on session recovery |
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | tests | Session Resume Hook — Reinject structured context on session recovery |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-session_start_hook_warning.yaml`*
*Last verified: 2026-05-01*
