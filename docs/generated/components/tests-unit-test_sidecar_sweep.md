# test_sidecar_sweep

> T-3418 — arc-011 sidecar sweep: the cron cadence for resolve_expired (slice 7).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_sidecar_sweep.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [outbox](/docs/generated/lib-sidecar-outbox) | uses | arc-011 sidecar — same-host outbox message/flag/ack substrate. |
| [delivery](/docs/generated/lib-sidecar-delivery) | uses | arc-011 sidecar — uniform delivery transport for the outbox. |
| [inbox](/docs/generated/lib-sidecar-inbox) | uses | arc-011 sidecar — inbox: consults addressed to this agent. |
| [status](/docs/generated/lib-sidecar-status) | uses | arc-011 sidecar — out-of-band status of the consult channel. |
| [sidecar_cli](/docs/generated/lib-sidecar_cli) | uses | `fw sidecar` — the callable surface of the arc-011 peer-consult sidecar. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_sidecar_sweep.yaml`*
*Last verified: 2026-09-22*
