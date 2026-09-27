# audit_flock

> Unit tests for agents/audit/audit.sh flock guard (T-1464) Verifies foreground audits also flock-protect (lifted T-1162's QUIET-only guard).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/audit_flock.bats`

## What It Does

Unit tests for agents/audit/audit.sh flock guard (T-1464)
Verifies foreground audits also flock-protect (lifted T-1162's QUIET-only guard).
T-3298: the behavioural collision tests originally asserted exit 0 — the
pre-T-2930 contract. T-2930 changed contention to exit 75 in ALL modes
("did not run" is not a verdict; see t2930_audit_contention_exit_code.bats).
These tests now pin the current contract: exit 75, foreground stderr message,
quiet-mode silence. The fixture was already hermetic (scratch PROJECT_ROOT /
CONTEXT_DIR, never the live lock) — only the asserted contract was stale.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_flock.yaml`*
*Last verified: 2026-04-25*
