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

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [inception](/docs/generated/lib-inception) | called_by | fw inception - Inception phase workflow |
| [lib_task_audit](/docs/generated/tests-unit-lib_task_audit) | called_by | TODO: describe what this component does |
| [lib_task_audit](/docs/generated/tests-unit-lib_task_audit) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-task-audit.yaml`*
*Last verified: 2026-04-11*
