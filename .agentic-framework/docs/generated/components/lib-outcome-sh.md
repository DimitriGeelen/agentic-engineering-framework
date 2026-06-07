# outcome-shim

> Thin shell shim that routes `fw outcome` invocations to lib/outcome.py. Per D-073: shim does PROJECT_ROOT export + argv passthrough only — no script-level logic.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/outcome.sh`

**Tags:** `orchestrator-arc`, `shim`, `T-1697`

## What It Does

Thin shim — routes `fw outcome` to lib/outcome.py.
Origin: T-1697 (production port of T-1690 inception spike, with append-only design pivot).

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [outcome](/docs/generated/lib-outcome) | calls | TODO: describe what this component does |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-outcome-sh.yaml`*
