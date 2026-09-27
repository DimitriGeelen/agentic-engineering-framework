# sidecar_cli

> `fw sidecar` — the callable surface of the arc-011 peer-consult sidecar.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/sidecar_cli.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [__init__](/docs/generated/lib-sidecar-__init__) | calls | arc-011 sidecar substrate (T-3402, T-3397 Amendment 5). |
| [e2e](/docs/generated/lib-sidecar-e2e) | calls | arc-011 sidecar — live end-to-end harness (T-3423, slice 9). |
| [__init__](/docs/generated/lib-sidecar-__init__) | uses | arc-011 sidecar substrate (T-3402, T-3397 Amendment 5). |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_sidecar_e2e](/docs/generated/tests-unit-test_sidecar_e2e) | uses_by | T-3423 — arc-011 sidecar slice 9: the end-to-end harness state machine. |
| [test_sidecar_sweep](/docs/generated/tests-unit-test_sidecar_sweep) | uses_by | T-3418 — arc-011 sidecar sweep: the cron cadence for resolve_expired (slice 7). |

---
*Auto-generated from Component Fabric. Card: `lib-sidecar_cli.yaml`*
*Last verified: 2026-09-21*
