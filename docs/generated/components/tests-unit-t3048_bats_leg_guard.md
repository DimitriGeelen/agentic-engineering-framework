# t3048_bats_leg_guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3048_bats_leg_guard.bats`

## What It Does

T-3048 — `fw test unit` and `fw test all` must skip, not hard-error, when the
install ships no tests/unit/.
Both legs are exercised against a synthetic FRAMEWORK_ROOT rather than by
reading bin/fw, because the defect was behavioural: the code "looked fine"
next to four sibling legs that happened to carry the guard it lacked.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3048_bats_leg_guard.yaml`*
*Last verified: 2026-08-16*
