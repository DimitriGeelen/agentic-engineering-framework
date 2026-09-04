# check-worktree-governance-write

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-worktree-governance-write.sh`

## What It Does

T-3098 — Refuse governance writes from a linked git worktree.
Executes slice 1 of T-2822's GO (operator, 2026-08-06). The mechanism, in
T-2822's words: governance state is TRACKED CONTENT, so a worktree is by
construction a fork of the governance state, and it begins diverging the
moment either side writes. Source-only therefore cannot be implemented by
keeping state OUT of a worktree — git puts it there — only by refusing to
WRITE to the copy git put there.
Scope, and why the blast radius is bounded by construction: a PreToolUse hook
governs AGENT TOOL CALLS, not writes performed inside scripts (the Tier 0
scope boundary, CLAUDE.md §Enforcement Tiers). `fw integrate`, `fw worktree`,

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [t3112_worktree_hook_parity](/docs/generated/tests-unit-t3112_worktree_hook_parity) | called_by | TODO: describe what this component does |
| [t3113_upgrade_worktree_advisory](/docs/generated/tests-unit-t3113_upgrade_worktree_advisory) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-worktree-governance-write.yaml`*
*Last verified: 2026-09-03*
