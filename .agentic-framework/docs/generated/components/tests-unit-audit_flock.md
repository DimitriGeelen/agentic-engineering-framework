# audit_flock

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_flock.bats`

## What It Does

Unit tests for agents/audit/audit.sh flock guard (T-1464)
Verifies foreground audits also flock-protect (lifted T-1162's QUIET-only guard).

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `C-004` | calls |
| `C-004` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_flock.yaml`*
*Last verified: 2026-04-25*
