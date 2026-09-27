# aef_election

> T-3310 (arc-020 S4): claim-based election for exactly-one provisioning.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/aef_election.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [aef_address](/docs/generated/lib-aef_address) | uses | T-3307 (arc-020 S1): V9 address grammar library. |
| [aef_circuit](/docs/generated/lib-aef_circuit) | uses | T-3308 (arc-020 S2): circuit registry + three-state lifecycle. |
| [aef_resolve](/docs/generated/lib-aef_resolve) | uses | T-3309 (arc-020 S3): regressive resolution + provisioning ladder. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [aef_repo_source](/docs/generated/lib-aef_repo_source) | uses_by | T-3312 (arc-020 S6): fleet repo-source + integrity verify. |
| [aef_resolve](/docs/generated/lib-aef_resolve) | uses_by | T-3309 (arc-020 S3): regressive resolution + provisioning ladder. |

---
*Auto-generated from Component Fabric. Card: `lib-aef_election.yaml`*
*Last verified: 2026-09-07*
