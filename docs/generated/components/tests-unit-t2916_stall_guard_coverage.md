# t2916_stall_guard_coverage

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2916_stall_guard_coverage.bats`

## What It Does

T-2916 — the stall guard must JUDGE, not merely run.
T-2914 shipped `--stall-after` and closed with 6/6 ACs green. Every one of
those ACs verified the guard was *wired* — flag parsed, banner printed, verb
exits 0. None verified it reached a verdict on real data. It did not: the
predicate required `task_snapshot`, a field T-2914 itself introduced, so its
evaluable history was empty on day one (measured 11/1325 rows = 0.8%) and it
abstained on 100% of its input while printing the same line as a guard that
had cleared everything.
These legs pin the three things that were wrong, each in BOTH directions so
the suite cannot pass by reporting everything or nothing.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | calls | TODO: describe what this component does |
| [resolver](/docs/generated/lib-resolver) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2916_stall_guard_coverage.yaml`*
*Last verified: 2026-08-11*
