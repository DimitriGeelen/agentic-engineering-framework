# revisit-due-scan

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/revisit-due-scan.sh`

## What It Does

revisit-due-scan.sh — Daily scan for ripe revisit_at deferrals (T-1452 / G-053)
Scans $PROJECT_ROOT/.tasks/active/*.md for frontmatter `revisit_at: <YYYY-MM-DD>`
entries whose date is <= today (UTC). Writes ripe matches to
.context/working/.revisits-due.txt — one line per task:
T-XXX fires YYYY-MM-DD: <name>
When no tasks are ripe the output file is removed entirely so downstream
readers (handover banner, Watchtower) can treat "file absent" and "file
empty" as the same signal — nothing to surface.
Idempotent: re-running on the same day produces the same output.
Designed to run from cron (silent on success, log to stderr on error).

---
*Auto-generated from Component Fabric. Card: `agents-context-revisit-due-scan.yaml`*
*Last verified: 2026-05-15*
