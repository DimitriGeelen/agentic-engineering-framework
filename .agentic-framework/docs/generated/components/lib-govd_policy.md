# govd_policy

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/govd_policy.py`

## What It Does

Default deployed location — RO to the agent uid in a real cage (Lock-1 Part 1).
Overridable so the check works in dev / test without a real install.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_relay](/docs/generated/lib-govd_relay) | calls | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [test_govd_policy](/docs/generated/tests-unit-test_govd_policy) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-govd_policy.yaml`*
*Last verified: 2026-06-18*
