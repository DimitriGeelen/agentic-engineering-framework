# test_orchestrator_routes

> Pin the `fw orchestrator routes` CLI surface (T-1789): mirror of web /orchestrator's route-cache view. Covers missing-cache, empty model_stats, invalid JSON, candidate sorting, --json shape parity with web _route_cache_learned, last_used surfacing.


**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_orchestrator_routes.py`

**Tags:** `arc:orchestrator-rethink`, `test`, `observability`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_orchestrator_routes.yaml`*
*Last verified: 2026-05-11*
