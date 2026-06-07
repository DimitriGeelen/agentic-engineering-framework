# audit_blocks_review_and_decide

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/integration/audit_blocks_review_and_decide.bats`

## What It Does

Integration tests for the placeholder audit chokepoint (T-1111/T-1113).
Verifies that `fw task review` and `fw inception decide` both refuse
to proceed when a task file contains literal template placeholders.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-audit_blocks_review_and_decide.yaml`*
*Last verified: 2026-04-11*
