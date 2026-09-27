# hook_portability

> Single source of truth for "is this hook command host-portable?" (T-2709).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/hook_portability.py`

## What It Does

Framework hook = dispatches through `fw hook <name>`. Anything else is a

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [hook_parity](/docs/generated/lib-hook_parity) | called_by | Hook-set extraction and comparison — ONE definition, every caller (T-3112/T-3113). |
| [upgrade](/docs/generated/lib-upgrade) | called_by | fw upgrade - Sync framework improvements to a consumer project |

---
*Auto-generated from Component Fabric. Card: `lib-hook_portability.yaml`*
*Last verified: 2026-09-03*
