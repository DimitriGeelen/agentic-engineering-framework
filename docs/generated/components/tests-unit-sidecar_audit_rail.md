# sidecar_audit_rail

> T-3420 — arc-011 sidecar slice 8: the audit rail over the consult ledger.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/sidecar_audit_rail.bats`

## What It Does

T-3420 — arc-011 sidecar slice 8: the audit rail over the consult ledger.
`fw_sidecar_ledger_facts <root>` (lib/sidecar-audit.sh) is the fact function
behind audit.sh's check_sidecar_ledger. It prints one tab-separated line
UNKNOWN  EXPIRED_UNSWEPT  STORED  DELIVERED  TOTAL  DEAD_LETTERS
read from the sidecar's own files under <root> — never the hub.
T-3434 appended a sixth field, DEAD_LETTERS: the subset of UNKNOWN the
universal retry ladder gave up on (`ladder-exhausted` / `ladder-unretryable`).
It is named separately from UNKNOWN because the remedy differs — an UNKNOWN
the ladder is still working needs patience, a dead-letter needs a decision.
States pinned here against a fixture ledger: never used (silent, rc 1), clean

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [sidecar-audit](/docs/generated/lib-sidecar-audit) | tests | lib/sidecar-audit.sh — arc-011 sidecar slice 8 (T-3420). |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [outbox](/docs/generated/lib-sidecar-outbox) | tests | arc-011 sidecar — same-host outbox message/flag/ack substrate. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-sidecar_audit_rail.yaml`*
*Last verified: 2026-09-22*
