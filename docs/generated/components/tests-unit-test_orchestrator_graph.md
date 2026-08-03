# test_orchestrator_graph

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_orchestrator_graph.bats`

## What It Does

T-2339 (arc-011 M1 §1) — orchestrator-graph dispatch decision.
Pins `agents/orchestrator/orchestrator-graph.py` + `fw orchestrator next-dispatch`:
- 2 disjoint tasks → both parallel
- 2 overlapping tasks → 1 parallel 1 serial (later round)
- chain dependency (A→B→C) → A parallel, B+C serial
- empty active pool → exit 0 + empty output
- task without write_set → mode=serial (conservative undecidable handling)

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_orchestrator_graph.yaml`*
*Last verified: 2026-06-11*
