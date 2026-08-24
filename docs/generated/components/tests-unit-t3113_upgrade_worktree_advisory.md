# t3113_upgrade_worktree_advisory

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3113_upgrade_worktree_advisory.bats`

## What It Does

T-3113: `fw upgrade` names which linked worktrees are behind (R7 leg L4).
Exercises _t3113_emit_worktree_advisory directly against a REAL `git worktree
add` fixture. The helper was extracted from do_upgrade for exactly this reason
— the alternative is driving a ten-step upgrade to observe one advisory block,
which tests the upgrade harness rather than the claim.
THE CONSOLIDATION TESTS (bottom of the file) are the ones that protect the fix
rather than the feature. T-3112 consolidated the hook-comparison predicate and
asserted "bin/fw holds zero copies" — true, and blind to a THIRD copy sitting
in lib/upgrade.sh that no assertion looked at. The scan here is repo-wide and
counts definitions, so the next copy cannot hide in a file nobody thought to

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [upgrade](/docs/generated/lib-upgrade) | tests | fw upgrade - Sync framework improvements to a consumer project |
| [hook_parity](/docs/generated/lib-hook_parity) | tests | TODO: describe what this component does |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3113_upgrade_worktree_advisory.yaml`*
*Last verified: 2026-08-20*
