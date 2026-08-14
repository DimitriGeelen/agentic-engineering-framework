# yield-point

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/dispatch/yield-point.sh`

## What It Does

T-2338 (arc-011 M1 §2) — harness yield-point spike.
Single-host cooperative-poll mechanism. The orchestrator writes a flag file
at .context/working/.dispatch-flag with content like:
refuse-write:/abs/path/that/conflicts
Workers invoke `yield-point.sh check <target_path>` before each Write/Edit.
If the flag is present AND its content matches the target path, the script
prints a refusal on stderr and exits non-zero — the worker treats the
non-zero exit as "do not write".
Design properties:
- Pure file polling, zero IPC dependency. Works on single host without

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [orchestrator-graph](/docs/generated/agents-orchestrator-orchestrator-graph) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-dispatch-yield-point.yaml`*
*Last verified: 2026-06-11*
