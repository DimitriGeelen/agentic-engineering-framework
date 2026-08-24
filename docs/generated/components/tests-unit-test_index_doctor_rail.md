# test_index_doctor_rail

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_index_doctor_rail.bats`

## What It Does

The doctor/audit rail over the vector index — T-3013 (T-3005 slice 4).
Every verdict here is asserted against a fixture that produces a DIFFERENT
verdict from the same code. A check verified only in the state it normally
reports is not verified — this arc has already shipped four instruments that
were green because they could not be anything else (T-3004), and two more
caught mid-build in T-3011.
So: stale is proven against fresh, fresh against stale, unknown against both.

## Dependencies (7)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [index-health](/docs/generated/lib-index-health) | tests | TODO: describe what this component does |
| [config](/docs/generated/lib-config) | tests | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [index-health](/docs/generated/lib-index-health) | calls | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_index_doctor_rail.yaml`*
*Last verified: 2026-08-15*
