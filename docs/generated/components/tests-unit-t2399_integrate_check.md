# t2399_integrate_check

> T-2399: fw integrate check — L2 serialized-integration preflight (read-only).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2399_integrate_check.bats`

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
| [integrate](/docs/generated/lib-integrate) | tests | fw integrate — Layer 2 serialized-integration preflight (T-2399, T-2397 slice 1). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2399_integrate_check.yaml`*
*Last verified: 2026-06-14*
