# test_orchestrator_outcome_dedup

> T-1757 — Regression test for orchestrator status outcome dedup.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_orchestrator_outcome_dedup.py`

## What It Does

The fw script prints other lines before JSON; isolate the JSON object.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_orchestrator_outcome_dedup.yaml`*
*Last verified: 2026-05-05*
