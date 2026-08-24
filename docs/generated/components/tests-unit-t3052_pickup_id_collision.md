# t3052_pickup_id_collision

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3052_pickup_id_collision.bats`

## What It Does

T-3052 — a pickup id is a filename (lib/pickup.sh:566 builds
`${pickup_id}-${type}.yaml`), so reissuing one aims two envelopes at one path.
Two gaps had to line up and each is harmless alone:
A  pickup_next_id skipped auto-deferred/, so ids parked there were reissued
B  every landing was a clobbering `mv ... 2>/dev/null || true`
A decided WHERE B fired. B is what made the loss silent — no error, no count
change, `fw pickup status` identical before and after.
So the suite tests them separately, and mutates them separately: a test that
only passes when BOTH fixes are present cannot tell you which one is load-bearing.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [pickup](/docs/generated/lib-pickup) | calls | Cross-project pickup pipeline that validates, deduplicates, and processes incoming YAML envelopes into inception tasks |
| [pickup](/docs/generated/lib-pickup) | tests | Cross-project pickup pipeline that validates, deduplicates, and processes incoming YAML envelopes into inception tasks |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3052_pickup_id_collision.yaml`*
*Last verified: 2026-08-17*
