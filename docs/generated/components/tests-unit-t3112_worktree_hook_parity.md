# t3112_worktree_hook_parity

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3112_worktree_hook_parity.bats`

## What It Does

T-3112: fw doctor audits linked worktrees for enforcement drift (R7 leg L3).
Two things are under test and they fail differently:
1. THE PREDICATE (lib/hook-parity.sh) — exercised against a REAL `git
worktree add`, because the claim being made is about git's worktree
model: `--git-common-dir` names the main checkout from every checkout
alike, which is what makes "the authority" resolvable from a replica.
A fabricated directory layout would assert nothing about that.
2. THE ZERO-COPY INVARIANT — `bin/fw` must hold no copy of the predicate.
This is the test that protects the fix from being undone by the next
person who needs the comparison in a third place and copies it. The

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-parity](/docs/generated/lib-hook-parity) | tests | TODO: describe what this component does |
| [upgrade](/docs/generated/lib-upgrade) | tests | fw upgrade - Sync framework improvements to a consumer project |
| [hook_parity](/docs/generated/lib-hook_parity) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [checkpoint](/docs/generated/checkpoint) | calls | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3112_worktree_hook_parity.yaml`*
*Last verified: 2026-08-20*
