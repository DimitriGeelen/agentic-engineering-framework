# test-onboarding

> End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project.

**Type:** script | **Subsystem:** framework-core | **Location:** `agents/onboarding-test/test-onboarding.sh`

**Tags:** `test`, `onboarding`, `e2e`

## What It Does

Test Onboarding — End-to-End Flow Test for New Projects
Exercises the full onboarding path: init → first task → commit → audit → handover
Runs 8 checkpoints and reports PASS/WARN/FAIL for each.
Usage:
agents/onboarding-test/test-onboarding.sh              # Use temp dir (auto-cleanup)
agents/onboarding-test/test-onboarding.sh /path/to/dir  # Use specific dir (no cleanup)
agents/onboarding-test/test-onboarding.sh --keep        # Use temp dir, don't cleanup
agents/onboarding-test/test-onboarding.sh --quiet       # Machine-readable output
Exit codes: 0=all pass, 1=warnings, 2=failures
From T-307 inception GO → T-317 build task.

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `?` | uses | — |
| `?` | uses | — |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [budget-gate](/docs/generated/budget-gate) | calls | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [self-audit](/docs/generated/agents-audit-self-audit) | calls | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Related

### Tasks
- T-798: Shellcheck cleanup: remaining peripheral agent scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-onboarding-test-test-onboarding.yaml`*
*Last verified: 2026-03-04*
