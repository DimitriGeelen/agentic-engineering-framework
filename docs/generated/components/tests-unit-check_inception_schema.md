# check_inception_schema

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/check_inception_schema.bats`

## What It Does

Unit tests for check-inception-schema hook (T-2188).
Inception tasks must declare target_blast_radius (int 0..9) and voi_score
(float 0..1). The hook blocks Write/Edit on inception task files missing
these fields. Bypass: FW_ALLOW_INCEPTION_SCHEMA_DRIFT=1 (logged Tier-2).

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `agents/context/check-inception-schema.py` | tests | — |

---
*Auto-generated from Component Fabric. Card: `tests-unit-check_inception_schema.yaml`*
*Last verified: 2026-07-22*
