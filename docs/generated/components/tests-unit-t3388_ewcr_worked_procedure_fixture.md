# t3388_ewcr_worked_procedure_fixture

> T-3388 — the worked human-gate → registered-script → human-gate fixture validates against the FROZEN v1 schemas (T-3385) and carries no path, shell string or secret — only opaque catalogue refs (arch §6.2.1, cadence §5).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3388_ewcr_worked_procedure_fixture.bats`

## What It Does

T-3388 — the worked human-gate → registered-script → human-gate fixture
validates against the FROZEN v1 schemas (T-3385) and carries no path, shell
string or secret — only opaque catalogue refs (arch §6.2.1, cadence §5).
The Designer-side round-trip (Q-10) is peer-owned and NOT asserted here.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [ewcr-contracts-check](/docs/generated/tools-ewcr-contracts-check) | tests | EWCR contracts v1 — freeze check (T-3385, Arc 0 candidate 2). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3388_ewcr_worked_procedure_fixture.yaml`*
*Last verified: 2026-09-18*
