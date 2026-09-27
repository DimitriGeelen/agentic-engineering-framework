# test_sidecar_e2e

> T-3423 — arc-011 sidecar slice 9: the end-to-end harness state machine.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_sidecar_e2e.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [outbox](/docs/generated/lib-sidecar-outbox) | uses | arc-011 sidecar — same-host outbox message/flag/ack substrate. |
| [delivery](/docs/generated/lib-sidecar-delivery) | uses | arc-011 sidecar — uniform delivery transport for the outbox. |
| [inbox](/docs/generated/lib-sidecar-inbox) | uses | arc-011 sidecar — inbox: consults addressed to this agent. |
| [e2e](/docs/generated/lib-sidecar-e2e) | uses | arc-011 sidecar — live end-to-end harness (T-3423, slice 9). |
| [sidecar_cli](/docs/generated/lib-sidecar_cli) | uses | `fw sidecar` — the callable surface of the arc-011 peer-consult sidecar. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_sidecar_e2e.yaml`*
*Last verified: 2026-09-22*
