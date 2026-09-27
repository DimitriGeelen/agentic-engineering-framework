# orchestrator-graph

> Orchestrator-graph (arc-011 M1, T-2339): builds a write-set-overlap and dependency graph over active tasks and emits (task_id, parallel|serial) dispatch decisions; consumes lib.write_set.compare and yield-point.sh.

**Type:** script | **Subsystem:** framework-core | **Location:** `agents/orchestrator/orchestrator-graph.py`

## What It Does

Make lib/ importable

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [write_set](/docs/generated/lib-write_set) | calls | Disjoint write-set policy validator (T-2337, arc-011 M1 §3). |
| [yield-point](/docs/generated/agents-dispatch-yield-point) | calls | arc-011 M1 harness yield-point: cooperative-poll safety net that reads .context/working/.dispatch-flag and refuses conflicting writes during parallel dispatch (T-2338). |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `agents-orchestrator-orchestrator-graph.yaml`*
*Last verified: 2026-06-11*
