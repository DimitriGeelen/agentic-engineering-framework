# escalation-scan-v0

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/escalation-scan-v0.py`

## What It Does

T-1555 Layer B v1: stable machine-readable summary for cron consumers.
Watchtower / metrics / drift dashboards read this; the .md remains for humans.

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tools-escalation-scan-v0.yaml`*
*Last verified: 2026-07-22*
