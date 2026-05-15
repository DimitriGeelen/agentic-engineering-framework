# test_mirror_sync

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_mirror_sync.bats`

## What It Does

T-1594: Mirror cascade auto-recovery (T-1591 Prevention #3)
Build a self-contained git topology with three local bare repos acting as
`origin` and two `mirror_*` remotes, then exercise mirror_sync against the
four cases the auto-recovery contract must distinguish:
in-sync, ancestor (fast-forward), diverged, unreachable.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `lib/mirror.sh` | calls |
| `lib/mirror.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_mirror_sync.yaml`*
*Last verified: 2026-04-28*
