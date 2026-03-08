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
mitigates:    [R-XXX] references to risks.yaml
status:       active|partial|planned|disabled

## Related

### Tasks
- T-194: ISO 27001-aligned assurance model — control register, OE testing, risk-driven cron redesign
- T-207: Add YAML parse validation to audit — regression test for all project YAML files

---
*Auto-generated from Component Fabric. Card: `context-project-controls.yaml`*
*Last verified: 2026-03-04*
