# fabric_coverage_single_source

> T-2735 — "which watched source files have no fabric card?" must have exactly ONE answer in audit.sh, and it must be the canonical expander's.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/fabric_coverage_single_source.bats`

## What It Does

T-2735 — "which watched source files have no fabric card?" must have exactly
ONE answer in audit.sh, and it must be the canonical expander's.
T-1842 extracted expand_patterns.py as the single source of truth for the
glob + exclude predicate, after a parallel copy in register.sh / drift.sh
produced 5946 junk cards undetected for ~22 days. It migrated those two
callers. The two copies inside audit.sh were never migrated, so the surface
that reports a coverage verdict to the operator was the one still globbing
on its own.
The copy at :1405 had three independent zeroing defects (no PROJECT_ROOT
join, no recursive=True, no exclude) and reported through two pass() arms,

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [expand_patterns](/docs/generated/agents-fabric-lib-expand_patterns) | tests | Fabric — shared pattern expansion with exclude support (T-1842). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-fabric_coverage_single_source.yaml`*
*Last verified: 2026-08-02*
