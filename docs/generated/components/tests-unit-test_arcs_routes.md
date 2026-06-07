# test_arcs_routes

> Unit tests for /arcs and /arcs/<id> routes (T-1662) — Flask test_client pins index empty/populated, detail in-progress with three-question check, detail closed without check, 404 for unregistered, missing-task graceful render.

**Type:** script | **Subsystem:** testing | **Location:** `tests/unit/test_arcs_routes.py`

**Tags:** `arcs`, `watchtower`, `regression`, `t-1662`

## What It Does

Seed minimal PROJECT_ROOT

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_arcs_routes.yaml`*
*Last verified: 2026-05-01*
