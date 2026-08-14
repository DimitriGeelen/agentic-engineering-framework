# bpmn

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/bpmn/bpmn.sh`

## What It Does

fw bpmn — BPMN process diagram → AEF task compiler (Child-2 forward bridge).
Thin wrapper: routes `compile` to tools/bpmn_to_tasks.py. See agents/bpmn/AGENT.md.

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `agents-bpmn-bpmn.yaml`*
*Last verified: 2026-07-12*
