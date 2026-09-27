# t3443_audit_structure_framework_scope

> T-3443: `agents/audit/audit.sh --sections structure` ran two checks that are properties of the FRAMEWORK REPOSITORY, not of the project being audited: check_invariant_suite (`timeout 300 bats tests/lint/`, 110 tests) and the dead-negation…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3443_audit_structure_framework_scope.bats`

## What It Does

T-3443: `agents/audit/audit.sh --sections structure` ran two checks that are
properties of the FRAMEWORK REPOSITORY, not of the project being audited:
check_invariant_suite (`timeout 300 bats tests/lint/`, 110 tests) and the
dead-negation lint over `tests/` (T-3138/T-3191). Both ran regardless of
PROJECT_ROOT. Measured 2026-09-22: one fixture audit inside
tests/unit/fabric_watch_pattern_fitness.bats took ~4 min; that file shells
six such audits, needing 24+ min, and any verification line bundling it
under `timeout 900` exited 124 on every host (T-3435's close was blocked
twice on exactly this).
The fix gates both checks on `_t3443_project_is_framework_root` (resolved

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3443_audit_structure_framework_scope.yaml`*
*Last verified: 2026-09-23*
