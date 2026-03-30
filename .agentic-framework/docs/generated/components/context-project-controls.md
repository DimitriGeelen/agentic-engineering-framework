# controls

> Control register tracking framework enforcement mechanisms (gates, hooks, checks) and their implementation status.

**Type:** data | **Subsystem:** context-fabric | **Location:** `.context/project/controls.yaml`

**Tags:** `context`, `project-memory`

## What It Does

Control Register — Agentic Engineering Framework
Schema: 8 fields, flat YAML, greppable (D-Phase2-001)
Origin: T-194 Phase 2b
id:           CTL-XXX (unique, sequential)
name:         Short human name
type:         pretooluse|posttooluse|sessionstart|git_hook|script_gate|behavioral|monitoring|infrastructure|auditor
impl:         File path or CLAUDE.md §section
blocking:     true = prevents action, false = warns/logs
mitigates:    [R-XXX] references to concerns.yaml or archived risks (T-397)
status:       active|partial|planned|disabled

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `agents/audit/audit.sh` | read_by |

---
*Auto-generated from Component Fabric. Card: `context-project-controls.yaml`*
*Last verified: 2026-03-04*
