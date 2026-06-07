# lib_enums

> Unit tests for enums (23 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_enums.bats`

**Tags:** `enums`, `bats`, `unit-test`

## What It Does

Unit tests for lib/enums.sh
Tests validation functions: is_valid_status, is_valid_type,
is_valid_horizon, is_valid_transition, valid_transitions_for

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [enums](/docs/generated/lib-enums) | calls | Single source of truth for framework enumerations — valid statuses, workflow types, horizons, and status transitions. Provides is_valid_status(), is_valid_type(), is_valid_horizon(), is_valid_transition() functions. Replaces hardcoded lists previously duplicated across 6+ files. |
| [enums](/docs/generated/lib-enums) | tests | Single source of truth for framework enumerations — valid statuses, workflow types, horizons, and status transitions. Provides is_valid_status(), is_valid_type(), is_valid_horizon(), is_valid_transition() functions. Replaces hardcoded lists previously duplicated across 6+ files. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_enums.yaml`*
*Last verified: 2026-04-05*
