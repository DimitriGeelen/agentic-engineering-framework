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

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3112_worktree_hook_parity.yaml`*
*Last verified: 2026-08-20*
