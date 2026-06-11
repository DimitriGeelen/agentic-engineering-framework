# test_self_vendor_agents_md_filter

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_self_vendor_agents_md_filter.bats`

## What It Does

T-2304 (OBS-068): regression test for _self_vendor_agents .md filter
extension.
Pre-T-2304: lib/upgrade.sh:_self_vendor_agents filtered on `.sh + .py` only.
AGENT.md files (intelligence siblings, e.g., agents/resume/AGENT.md) drifted
silently between source agents/ and vendored .agentic-framework/agents/.
Origin: T-2301 hit this on the resume agent.
T-2304: filter extended to `.sh + .py + .md`. This test pins the .md leg so
any future refactor that narrows the filter trips the gate.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [upgrade](/docs/generated/lib-upgrade) | tests | fw upgrade - Sync framework improvements to a consumer project |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_self_vendor_agents_md_filter.yaml`*
*Last verified: 2026-06-10*
