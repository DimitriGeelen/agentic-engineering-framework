# hook_threshold

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/hook_threshold.bats`

## What It Does

T-1631 (B-3b of T-1626) — hook-failure threshold rule.
Pins the contract that:
1. lib/hook-threshold.py reads .hook-counter + .hook-failure-counter
2. Sums duplicate keys defensively (concurrent-write race in T-1628)
3. Threshold env vars override defaults (FW_HOOK_THRESHOLD_*)
4. Healthy state (no failures) emits nothing under threshold scan
5. Broken state (failures > threshold AND total >= min_fires) emits FAIL
6. --register upserts a G-XXX into concerns.yaml
7. --register is idempotent — already-open entry is skipped
8. After human closes a concern, re-occurrence creates a new entry

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-threshold](/docs/generated/lib-hook-threshold) | calls | TODO: describe what this component does |
| [hook-threshold](/docs/generated/lib-hook-threshold) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-hook_threshold.yaml`*
*Last verified: 2026-05-01*
