# ewcr-contracts-check

> EWCR contracts v1 — freeze check (T-3385, Arc 0 candidate 2).

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/ewcr-contracts-check.py`

## What It Does

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [t3385_ewcr_contracts_v1](/docs/generated/tests-unit-t3385_ewcr_contracts_v1) | tests_by | T-3385 — EWCR contracts v1 are FROZEN: seven draft 2020-12 schemas, one worked example each, sha256 manifest. tools/ewcr-contracts-check.py is the fence. |
| [t3388_ewcr_worked_procedure_fixture](/docs/generated/tests-unit-t3388_ewcr_worked_procedure_fixture) | tests_by | T-3388 — the worked human-gate → registered-script → human-gate fixture validates against the FROZEN v1 schemas (T-3385) and carries no path, shell string or secret — only opaque catalogue refs (arch §6.2.1, cadence §5). |

---
*Auto-generated from Component Fabric. Card: `tools-ewcr-contracts-check.yaml`*
*Last verified: 2026-09-18*
