# t2473_union_resolve

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2473_union_resolve.bats`

## What It Does

T-2473 — fw integrate run: true per-class UNION at both-sided conflicts.
Replaces the T-2471 MVP's blanket `checkout --ours` (which dropped the master
side's entries) with real union resolution. Each test drives a GENUINE git
conflict on a union-class file through `integrate run master` and asserts BOTH
sides' entries survive in the merged result — not ours-truncated.
Conflict is forced by having ours AND theirs both modify a shared anchor line
(guaranteed git conflict) AND each append its own distinct entry.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [integrate](/docs/generated/lib-integrate) | calls | TODO: describe what this component does |
| [integrate](/docs/generated/lib-integrate) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2473_union_resolve.yaml`*
*Last verified: 2026-06-24*
