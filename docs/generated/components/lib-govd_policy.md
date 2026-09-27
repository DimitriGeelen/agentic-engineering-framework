# govd_policy

> govd_policy — proxy-policy emit / install / drift (arc-013 / T-2432, design §4c).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/govd_policy.py`

## What It Does

Default deployed location — RO to the agent uid in a real cage (Lock-1 Part 1).
Overridable so the check works in dev / test without a real install.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [govd_relay](/docs/generated/lib-govd_relay) | calls | govd_relay — the governance mediation relay / proxy brain (arc-013 / T-2431). |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [test_govd_policy](/docs/generated/tests-unit-test_govd_policy) | called_by | T-2432 — pin proxy-policy emit/install/drift (arc-013, design §4c). |
| [enrich](/docs/generated/agents-fabric-lib-enrich) | called_by | Fabric enrichment engine — auto-detect dependency edges from source analysis. |

---
*Auto-generated from Component Fabric. Card: `lib-govd_policy.yaml`*
*Last verified: 2026-06-18*
