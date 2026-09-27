# test_workflow_schema_pause_lint

> Tests for the workflow schema linter (lib/workflow_lint.py).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_workflow_schema_pause_lint.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [workflow_lint](/docs/generated/lib-workflow_lint) | calls | Workflow schema linter for `.context/project/workflows/*.yaml`. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_workflow_schema_pause_lint.yaml`*
*Last verified: 2026-05-13*
