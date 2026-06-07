# pre-compact

> Pre-Compaction Hook — Save structured context before lossy compaction

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/pre-compact.sh`

## What It Does

Pre-Compaction Hook — Save structured context before lossy compaction
Fires on PreCompact — manual /compact only (auto-compaction disabled per D-027).
Generates a handover so that SessionStart:compact can
reinject structured context into the fresh session.
Part of: T-111 (Autonomous compact-resume lifecycle)
Updated: T-175 (D-028 — single handover, no emergency distinction)
Updated: T-177 (manual-only cleanup, D-027 documentation)

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [self-audit](/docs/generated/agents-audit-self-audit) | read_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [hook-config](/docs/generated/hook-config) | triggers_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [hook-config](/docs/generated/hook-config) | used-by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [pre_compact_flock](/docs/generated/tests-unit-pre_compact_flock) | called_by | TODO: describe what this component does |
| [pre_compact_flock](/docs/generated/tests-unit-pre_compact_flock) | tests_by | TODO: describe what this component does |
| [pre_compact_timewindow_dedup](/docs/generated/tests-unit-pre_compact_timewindow_dedup) | called_by | TODO: describe what this component does |
| [pre_compact_timewindow_dedup](/docs/generated/tests-unit-pre_compact_timewindow_dedup) | tests_by | TODO: describe what this component does |

## Related

### Tasks
- T-822: Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-context-pre-compact.yaml`*
*Last verified: 2026-02-20*
