# test_sidecar_termlink_transport

> T-3405 — arc-011 sidecar real TermLink transport + hub probe (Amendment 5, slice 3).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_sidecar_termlink_transport.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [outbox](/docs/generated/lib-sidecar-outbox) | uses | arc-011 sidecar — same-host outbox message/flag/ack substrate. |
| [delivery](/docs/generated/lib-sidecar-delivery) | uses | arc-011 sidecar — uniform delivery transport for the outbox. |
| [termlink_transport](/docs/generated/lib-sidecar-termlink_transport) | uses | arc-011 sidecar — real TermLink transport and hub capability probe. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_sidecar_termlink_transport.yaml`*
*Last verified: 2026-09-21*
