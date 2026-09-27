# test_mirror_sync

> T-1594: Mirror cascade auto-recovery (T-1591 Prevention #3)

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_mirror_sync.bats`

## What It Does

T-1594: Mirror cascade auto-recovery (T-1591 Prevention #3)
Build a self-contained git topology with three local bare repos acting as
`origin` and two `mirror_*` remotes, then exercise mirror_sync against the
four cases the auto-recovery contract must distinguish:
in-sync, ancestor (fast-forward), diverged, unreachable.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [mirror](/docs/generated/lib-mirror) | calls | lib/mirror.sh — Mirror cascade auto-recovery (T-1594, T-1591 Prevention #3). |
| [mirror](/docs/generated/lib-mirror) | tests | lib/mirror.sh — Mirror cascade auto-recovery (T-1594, T-1591 Prevention #3). |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_mirror_sync.yaml`*
*Last verified: 2026-04-28*
