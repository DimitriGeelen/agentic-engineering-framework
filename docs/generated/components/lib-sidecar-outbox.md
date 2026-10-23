# outbox

> arc-011 sidecar — same-host outbox message/flag/ack substrate.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/sidecar/outbox.py`

## What It Does

T-3717: the alias above renames the Python NAME only. Ledger rows written
before T-3561 still carry the literal string "INJECTED_NOW" on disk, and the
ledger is append-only, so they never go away. `_read_ledger` maps this value
to HUB_ACCEPTED so every reader (status counts, retry eligibility) still sees
those rows as delivered rather than as an unknown, retryable state.

## Used By (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [sidecar_audit_rail](/docs/generated/tests-unit-sidecar_audit_rail) | tests_by | T-3420 — arc-011 sidecar slice 8: the audit rail over the consult ledger. |
| [test_sidecar_delivery](/docs/generated/tests-unit-test_sidecar_delivery) | uses_by | T-3404 — arc-011 sidecar uniform delivery transport (T-3397 Amendment 5, slice 2). |
| [test_sidecar_e2e](/docs/generated/tests-unit-test_sidecar_e2e) | uses_by | T-3423 — arc-011 sidecar slice 9: the end-to-end harness state machine. |
| [test_sidecar_inbox](/docs/generated/tests-unit-test_sidecar_inbox) | uses_by | T-3406 — arc-011 sidecar inbox: cursor, dedupe, identity (slice 4). |
| [test_sidecar_outbox](/docs/generated/tests-unit-test_sidecar_outbox) | uses_by | T-3402 — arc-011 sidecar outbox substrate (T-3397 Amendment 5, slice 1). |
| [test_sidecar_status](/docs/generated/tests-unit-test_sidecar_status) | uses_by | T-3417 — arc-011 sidecar status: out-of-band observer (round-1 review Δ4). |
| [test_sidecar_sweep](/docs/generated/tests-unit-test_sidecar_sweep) | uses_by | T-3418 — arc-011 sidecar sweep: the cron cadence for resolve_expired (slice 7). |
| [test_sidecar_termlink_transport](/docs/generated/tests-unit-test_sidecar_termlink_transport) | uses_by | T-3405 — arc-011 sidecar real TermLink transport + hub probe (Amendment 5, slice 3). |

---
*Auto-generated from Component Fabric. Card: `lib-sidecar-outbox.yaml`*
*Last verified: 2026-09-21*
