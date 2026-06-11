# test_arc010_hm_a_demo_evidence

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/integration/test_arc010_hm_a_demo_evidence.bats`

## What It Does

T-2268 (arc-010 Slice 3 HM-A): integration contract test for the demo evidence
README + traceability shape.
This is the test the operator runs *after* the demo agent completes its run.
It enforces:
- Evidence README exists at the canonical path
- README contains the headline_mechanic verbatim from the arc YAML
- README's traceability table contains a row for each headline_mechanic clause
- When transcript JSONL is present, structural greps match expected shape
Tests are designed to skip (not fail) cleanly when the demo has not yet run.
This lets the test live on master green throughout arc-010 development; it

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-test_arc010_hm_a_demo_evidence.yaml`*
*Last verified: 2026-06-08*
