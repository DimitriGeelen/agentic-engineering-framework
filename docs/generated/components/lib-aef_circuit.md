# aef_circuit

> T-3308 (arc-020 S2): circuit registry + three-state lifecycle.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/aef_circuit.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [aef_address](/docs/generated/lib-aef_address) | calls | T-3307 (arc-020 S1): V9 address grammar library. |
| [aef_address](/docs/generated/lib-aef_address) | uses | T-3307 (arc-020 S1): V9 address grammar library. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [aef_election](/docs/generated/lib-aef_election) | uses_by | T-3310 (arc-020 S4): claim-based election for exactly-one provisioning. |
| [aef_resolve](/docs/generated/lib-aef_resolve) | called_by | T-3309 (arc-020 S3): regressive resolution + provisioning ladder. |
| [aef_resolve](/docs/generated/lib-aef_resolve) | uses_by | T-3309 (arc-020 S3): regressive resolution + provisioning ladder. |

---
*Auto-generated from Component Fabric. Card: `lib-aef_circuit.yaml`*
*Last verified: 2026-09-07*
