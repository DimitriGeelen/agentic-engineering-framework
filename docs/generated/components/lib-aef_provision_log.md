# aef_provision_log

> T-3313 (arc-020 S7): durable JSONL audit trail for auto-provision events.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/aef_provision_log.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [aef_resolve](/docs/generated/lib-aef_resolve) | calls | T-3309 (arc-020 S3): regressive resolution + provisioning ladder. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-aef_provision_log.yaml`*
*Last verified: 2026-09-07*
