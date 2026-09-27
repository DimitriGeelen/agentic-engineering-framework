# test_govd_sandbox

> T-2433 (arc-013): sandbox profile emit / status / install — the static floor.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_govd_sandbox.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_sandbox](/docs/generated/lib-govd_sandbox) | calls | govd_sandbox — OS sandbox profile emit / install / drift (arc-013 / T-2433, design §7a). |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_govd_sandbox.yaml`*
*Last verified: 2026-09-20*
