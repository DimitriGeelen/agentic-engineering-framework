# claude-fw

> Claude Code wrapper with auto-restart support. Runs claude normally, then checks for a restart signal file written by checkpoint.sh when auto-handover fires at critical budget. If found and fresh, auto-restarts with claude -c to continue seamlessly.

**Type:** script | **Subsystem:** framework-core | **Location:** `bin/claude-fw`

## What It Does

claude-fw — Claude Code wrapper with auto-restart support
Runs claude normally, then checks for a restart signal file
written by checkpoint.sh when auto-handover fires at critical budget.
If found (and fresh), auto-restarts with `claude -c` to continue.
Usage:
claude-fw [claude-args...]          # Run with auto-restart enabled
claude-fw --no-restart [args...]    # Run without auto-restart
The restart signal file is .context/working/.restart-requested
Written by: checkpoint.sh auto-handover at critical budget (T-186)
Consumed by: this script on claude exit

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `C-008` | reads |

---
*Auto-generated from Component Fabric. Card: `bin-claude-fw.yaml`*
*Last verified: 2026-03-01*
