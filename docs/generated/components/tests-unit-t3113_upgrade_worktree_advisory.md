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

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3113_upgrade_worktree_advisory.yaml`*
*Last verified: 2026-08-20*
