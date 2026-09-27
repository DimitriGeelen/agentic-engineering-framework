# aef_resolve

> T-3309 (arc-020 S3): regressive resolution + provisioning ladder.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/aef_resolve.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [aef_address](/docs/generated/lib-aef_address) | calls | T-3307 (arc-020 S1): V9 address grammar library. |
| [aef_circuit](/docs/generated/lib-aef_circuit) | calls | T-3308 (arc-020 S2): circuit registry + three-state lifecycle. |
| [aef_address](/docs/generated/lib-aef_address) | uses | T-3307 (arc-020 S1): V9 address grammar library. |
| [aef_circuit](/docs/generated/lib-aef_circuit) | uses | T-3308 (arc-020 S2): circuit registry + three-state lifecycle. |
| [aef_election](/docs/generated/lib-aef_election) | uses | T-3310 (arc-020 S4): claim-based election for exactly-one provisioning. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [aef_election](/docs/generated/lib-aef_election) | uses_by | T-3310 (arc-020 S4): claim-based election for exactly-one provisioning. |
| [aef_provision_log](/docs/generated/lib-aef_provision_log) | called_by | T-3313 (arc-020 S7): durable JSONL audit trail for auto-provision events. |
| [aef_repo_source](/docs/generated/lib-aef_repo_source) | called_by | T-3312 (arc-020 S6): fleet repo-source + integrity verify. |
| [aef_repo_source](/docs/generated/lib-aef_repo_source) | uses_by | T-3312 (arc-020 S6): fleet repo-source + integrity verify. |

---
*Auto-generated from Component Fabric. Card: `lib-aef_resolve.yaml`*
*Last verified: 2026-09-07*
