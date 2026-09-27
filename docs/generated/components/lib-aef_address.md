# aef_address

> T-3307 (arc-020 S1): V9 address grammar library.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/aef_address.py`

## What It Does

Ladder climb order: rightmost token first (level 5 down to level 2).

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [aef_circuit](/docs/generated/lib-aef_circuit) | called_by | T-3308 (arc-020 S2): circuit registry + three-state lifecycle. |
| [aef_circuit](/docs/generated/lib-aef_circuit) | uses_by | T-3308 (arc-020 S2): circuit registry + three-state lifecycle. |
| [aef_election](/docs/generated/lib-aef_election) | uses_by | T-3310 (arc-020 S4): claim-based election for exactly-one provisioning. |
| [aef_resolve](/docs/generated/lib-aef_resolve) | called_by | T-3309 (arc-020 S3): regressive resolution + provisioning ladder. |
| [aef_resolve](/docs/generated/lib-aef_resolve) | uses_by | T-3309 (arc-020 S3): regressive resolution + provisioning ladder. |

---
*Auto-generated from Component Fabric. Card: `lib-aef_address.yaml`*
*Last verified: 2026-09-07*
