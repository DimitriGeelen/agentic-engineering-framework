# t2399_integrate_check

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2399_integrate_check.bats`

## What It Does

T-2399: fw integrate check — L2 serialized-integration preflight (read-only).
Encodes the T-2397 §3.2 un-partitionable-file taxonomy and reports how the
current worktree branch would integrate onto master:
exit 0 ff-ready|clean, 1 auto-resolvable, 2 needs-human, 3 not-on-branch, 4 error.
Tests drive REAL git repos with controlled divergence (zero mocks) + direct
classify_path() unit checks.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [integrate](/docs/generated/lib-integrate) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2399_integrate_check.yaml`*
*Last verified: 2026-06-14*
