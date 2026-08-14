# orchestrator-graph

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/orchestrator/orchestrator-graph.py`

## What It Does

Make lib/ importable

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [write_set](/docs/generated/lib-write_set) | calls | TODO: describe what this component does |
| [yield-point](/docs/generated/agents-dispatch-yield-point) | calls | TODO: describe what this component does |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `agents-orchestrator-orchestrator-graph.yaml`*
*Last verified: 2026-06-11*
