# test_spawn

> T-1773: Unit tests for lib/spawn.py.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_spawn.py`

## What It Does

Force-reload spawn so PROJECT_ROOT-derived constants reflect the tmp dir

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [spawn](/docs/generated/lib-spawn) | calls | spawn — dispatch driver: read resolver envelope, spawn worker, finalise outcome. |
| [resolver](/docs/generated/lib-resolver) | calls | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_spawn.yaml`*
*Last verified: 2026-05-06*
