# hook-config

> Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns.

**Type:** config | **Subsystem:** enforcement | **Location:** `.claude/settings.json`

**Tags:** `hooks`, `enforcement`, `PreToolUse`, `PostToolUse`, `configuration`

## What It Does

## Dependencies (8)

| Target | Relationship |
|--------|-------------|
| `agents/context/check-active-task.sh` | triggers |
| `agents/context/check-tier0.sh` | triggers |
| `C-007` | triggers |
| `C-008` | triggers |
| `agents/context/error-watchdog.sh` | triggers |
| `agents/context/check-dispatch.sh` | triggers |
| `agents/context/pre-compact.sh` | triggers |
| `agents/context/post-compact-resume.sh` | triggers |

## Related

### Tasks
- T-242: Block built-in EnterPlanMode from bypassing framework governance

---
*Auto-generated from Component Fabric. Card: `hook-config.yaml`*
*Last verified: 2026-02-20*
