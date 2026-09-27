# delivery

> arc-011 sidecar — uniform delivery transport for the outbox.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/sidecar/delivery.py`

## What It Does

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_sidecar_delivery](/docs/generated/tests-unit-test_sidecar_delivery) | uses_by | T-3404 — arc-011 sidecar uniform delivery transport (T-3397 Amendment 5, slice 2). |
| [test_sidecar_e2e](/docs/generated/tests-unit-test_sidecar_e2e) | uses_by | T-3423 — arc-011 sidecar slice 9: the end-to-end harness state machine. |
| [test_sidecar_status](/docs/generated/tests-unit-test_sidecar_status) | called_by | T-3417 — arc-011 sidecar status: out-of-band observer (round-1 review Δ4). |
| [test_sidecar_status](/docs/generated/tests-unit-test_sidecar_status) | uses_by | T-3417 — arc-011 sidecar status: out-of-band observer (round-1 review Δ4). |
| [test_sidecar_sweep](/docs/generated/tests-unit-test_sidecar_sweep) | uses_by | T-3418 — arc-011 sidecar sweep: the cron cadence for resolve_expired (slice 7). |
| [test_sidecar_termlink_transport](/docs/generated/tests-unit-test_sidecar_termlink_transport) | uses_by | T-3405 — arc-011 sidecar real TermLink transport + hub probe (Amendment 5, slice 3). |

---
*Auto-generated from Component Fabric. Card: `lib-sidecar-delivery.yaml`*
*Last verified: 2026-09-21*
