# task-audit

> Scans task files for literal placeholder content that should have been replaced during authoring, blocking review and inception decisions until resolved

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/task-audit.sh`

## What It Does

lib/task-audit.sh — Placeholder audit chokepoint for task files (T-1111/T-1113)
Scans a task file for literal placeholder content that should have been
replaced during authoring. Exists to close the L-006 bleed-through class
documented in docs/reports/T-1111-placeholder-sections-rca.md and to
resolve G-018 (silent quality decay).
Called by:
- bin/fw task review  (before emit_review marker creation)
- lib/inception.sh:do_inception_decide  (before marker/recommendation checks)
Usage:
source "$FW_LIB_DIR/task-audit.sh"

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `lib/inception.sh` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-task-audit.yaml`*
*Last verified: 2026-04-11*
