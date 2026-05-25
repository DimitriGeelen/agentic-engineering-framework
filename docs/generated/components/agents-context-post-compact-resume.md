# post-compact-resume

> Session Resume Hook — Reinject structured context on session recovery

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/post-compact-resume.sh`

## What It Does

Session Resume Hook — Reinject structured context on session recovery
Fires on SessionStart with matchers "compact" and "resume" (T-188).
Outputs additionalContext JSON so Claude has framework state immediately.
Triggers:
- After /compact (manual compaction recovery)
- After claude -c (session continuation, including auto-restart via T-179)
Part of: T-111 (compact-resume), T-179/T-188 (auto-restart)

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fabric](/docs/generated/agents-fabric-fabric) | calls | Fabric Agent - Component topology system for codebase self-awareness |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [doctor-hook-exercise](/docs/generated/lib-doctor-hook-exercise) | calls | TODO: describe what this component does |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [self-audit](/docs/generated/agents-audit-self-audit) | read_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [hook-config](/docs/generated/hook-config) | triggers_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [hook-config](/docs/generated/hook-config) | used-by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [session_start_hook_warning](/docs/generated/tests-unit-session_start_hook_warning) | called_by | TODO: describe what this component does |
| [session_start_hook_warning](/docs/generated/tests-unit-session_start_hook_warning) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-post-compact-resume.yaml`*
*Last verified: 2026-02-20*
