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

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `agents/audit/self-audit.sh` | read_by |

## Related

### Tasks
- T-559: Project boundary gate — PreToolUse hook blocking writes outside PROJECT_ROOT
- T-591: Commit cadence warning — PostToolUse hook counting edits since last commit
- T-663: Fix framework hooks — replace bare fw with bin/fw in settings.json

---
*Auto-generated from Component Fabric. Card: `hook-config.yaml`*
*Last verified: 2026-02-20*
