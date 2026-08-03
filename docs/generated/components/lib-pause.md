# pause

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/pause.sh`

## What It Does

Thin shim — routes `fw pause` to lib/pause_cli.py.
Origin: T-1809 (dispatch-safety slice 5).

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-pause.yaml`*
*Last verified: 2026-05-13*
