# hook_parity

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/hook_parity.py`

## What It Does

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-parity](/docs/generated/lib-hook-parity) | calls | TODO: describe what this component does |
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [t3111_worktree_reexec](/docs/generated/tests-unit-t3111_worktree_reexec) | tests_by | TODO: describe what this component does |
| [t3112_worktree_hook_parity](/docs/generated/tests-unit-t3112_worktree_hook_parity) | tests_by | TODO: describe what this component does |
| [t3113_upgrade_worktree_advisory](/docs/generated/tests-unit-t3113_upgrade_worktree_advisory) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-hook_parity.yaml`*
*Last verified: 2026-08-20*
