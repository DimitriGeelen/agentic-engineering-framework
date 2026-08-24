# t3053_multiref_traceability

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3053_multiref_traceability.bats`

## What It Does

T-3053 — a commit subject may name more than one task. The traceability check
read only the first ref, so a commit whose leading ref did not resolve was
reported orphaned even when a later ref named a real task.
Two sites carried the same `head -1` shape and they ask opposite questions:
commit subject   "is this commit traceable?"   -> ANY ref resolving suffices
practice Origin  "are these citations valid?"  -> EVERY ref must resolve
So one defect was a false FAIL at one site and a false GREEN at the other, and
the two need opposite fixes. Every test below pins a direction, not just a
behaviour, and both fixes are mutation-checked against a copy of audit.sh with
the `head -1` form restored.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3053_multiref_traceability.yaml`*
*Last verified: 2026-08-16*
