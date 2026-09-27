# t3385_ewcr_contracts_v1

> T-3385 — EWCR contracts v1 are FROZEN: seven draft 2020-12 schemas, one worked example each, sha256 manifest. tools/ewcr-contracts-check.py is the fence.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3385_ewcr_contracts_v1.bats`

## What It Does

T-3385 — EWCR contracts v1 are FROZEN: seven draft 2020-12 schemas, one worked
example each, sha256 manifest. tools/ewcr-contracts-check.py is the fence.
Every green assertion here has a control leg showing the same fence red on a
tampered copy (L-668) — a check that cannot fail is not a check.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [ewcr-contracts-check](/docs/generated/tools-ewcr-contracts-check) | tests | EWCR contracts v1 — freeze check (T-3385, Arc 0 candidate 2). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3385_ewcr_contracts_v1.yaml`*
*Last verified: 2026-09-18*
