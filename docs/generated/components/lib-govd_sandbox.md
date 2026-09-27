# govd_sandbox

> govd_sandbox — OS sandbox profile emit / install / drift (arc-013 / T-2433, design §7a).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/govd_sandbox.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [test_govd_sandbox](/docs/generated/tests-unit-test_govd_sandbox) | called_by | T-2433 (arc-013): sandbox profile emit / status / install — the static floor. |

---
*Auto-generated from Component Fabric. Card: `lib-govd_sandbox.yaml`*
*Last verified: 2026-09-20*
