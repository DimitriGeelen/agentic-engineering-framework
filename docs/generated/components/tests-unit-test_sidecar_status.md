# test_sidecar_status

> T-3417 — arc-011 sidecar status: out-of-band observer (round-1 review Δ4).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_sidecar_status.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [delivery](/docs/generated/lib-sidecar-delivery) | calls | arc-011 sidecar — uniform delivery transport for the outbox. |
| [delivery](/docs/generated/lib-sidecar-delivery) | uses | arc-011 sidecar — uniform delivery transport for the outbox. |
| [outbox](/docs/generated/lib-sidecar-outbox) | uses | arc-011 sidecar — same-host outbox message/flag/ack substrate. |
| [inbox](/docs/generated/lib-sidecar-inbox) | uses | arc-011 sidecar — inbox: consults addressed to this agent. |
| [status](/docs/generated/lib-sidecar-status) | uses | arc-011 sidecar — out-of-band status of the consult channel. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_sidecar_status.yaml`*
*Last verified: 2026-09-22*
