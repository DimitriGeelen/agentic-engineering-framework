# static_scan

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/reviewer/static_scan.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [overrides](/docs/generated/lib-reviewer-overrides) | calls | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [audit](/docs/generated/lib-reviewer-audit) | called_by | TODO: describe what this component does |
| [drift_cli](/docs/generated/lib-reviewer-drift_cli) | called_by | TODO: describe what this component does |
| [audit-swallowed-errors](/docs/generated/tools-audit-swallowed-errors) | called_by | TODO: describe what this component does |
| [g066_readiness](/docs/generated/tests-unit-g066_readiness) | tests_by | TODO: describe what this component does |
| [g066-readiness](/docs/generated/tools-g066-readiness) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-reviewer-static_scan.yaml`*
*Last verified: 2026-05-06*
