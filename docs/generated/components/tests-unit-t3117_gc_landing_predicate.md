# t3117_gc_landing_predicate

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3117_gc_landing_predicate.bats`

## What It Does

T-3117: `fw worktree gc` decides "has this landed?" against the right trunk,
and by the right test.
Two defects, both of which made gc report landed work as unlanded — the
direction that is safe to be wrong in exactly once, and then never gets
revisited because "it says there is unlanded work" reads as a good reason to
leave a worktree alone.
1. TRUNK. _wt_master_ref preferred refs/heads/master. In the session-on-master
flow (T-100196) work lands by pushing HEAD:master from a topic branch,
which advances origin/master and never touches the local master branch.
Measured in the live repo on 2026-08-23: local master 1744 commits behind.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [worktree](/docs/generated/lib-worktree) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3117_gc_landing_predicate.yaml`*
*Last verified: 2026-08-23*
