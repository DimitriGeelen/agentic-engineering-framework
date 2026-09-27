# hook_parity

> Hook-set extraction and comparison — ONE definition, every caller (T-3112/T-3113).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/hook_parity.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-parity](/docs/generated/lib-hook-parity) | calls | lib/hook-parity.sh — the enforcement-baseline comparison predicate (T-3112, R7 leg 3) |
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [hook_portability](/docs/generated/lib-hook_portability) | calls | Single source of truth for "is this hook command host-portable?" (T-2709). |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [t3111_worktree_reexec](/docs/generated/tests-unit-t3111_worktree_reexec) | tests_by | T-3111: fw re-execs the AUTHORITY's binary from a linked worktree (R7 leg L2). |
| [t3112_worktree_hook_parity](/docs/generated/tests-unit-t3112_worktree_hook_parity) | tests_by | T-3112: fw doctor audits linked worktrees for enforcement drift (R7 leg L3). |
| [t3113_upgrade_worktree_advisory](/docs/generated/tests-unit-t3113_upgrade_worktree_advisory) | tests_by | T-3113: `fw upgrade` names which linked worktrees are behind (R7 leg L4). |

---
*Auto-generated from Component Fabric. Card: `lib-hook_parity.yaml`*
*Last verified: 2026-08-20*
