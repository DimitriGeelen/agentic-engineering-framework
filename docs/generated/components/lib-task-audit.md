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

## Used By (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [inception](/docs/generated/lib-inception) | called_by | fw inception - Inception phase workflow |
| [lib_task_audit](/docs/generated/tests-unit-lib_task_audit) | called_by | TODO: describe what this component does |
| [lib_task_audit](/docs/generated/tests-unit-lib_task_audit) | tests_by | TODO: describe what this component does |
| [active-task-scan](/docs/generated/agents-audit-active-task-scan) | called_by | Single-pass scan of active task files that checks compliance, quality, research artifacts, ownership, and review queue status in one efficient pass |
| [t2945_default_template_recommendation](/docs/generated/tests-unit-t2945_default_template_recommendation) | called_by | TODO: describe what this component does |
| [t2945_default_template_recommendation](/docs/generated/tests-unit-t2945_default_template_recommendation) | tests_by | TODO: describe what this component does |
| [review](/docs/generated/lib-review) | called_by | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |

---
*Auto-generated from Component Fabric. Card: `lib-task-audit.yaml`*
*Last verified: 2026-04-11*
