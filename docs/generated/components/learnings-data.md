# learnings-data

> Persistent store of all project learnings. Read by web UI and audit. Written by add-learning command.

**Type:** data | **Subsystem:** learnings-pipeline | **Location:** `.context/project/learnings.yaml`

**Tags:** `learning`, `memory`, `project-memory`, `yaml`

## What It Does

Project Learnings - Knowledge gained during development
Added via: fw context add-learning "description" --task T-XXX

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [add-learning](/docs/generated/add-learning) | writes_by | Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | read_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [learnings-route](/docs/generated/learnings-route) | read_by | Serve the /learnings page showing all project learnings, patterns, and practices. |

## Related

### Tasks
- T-937: Commit pending handover checkpoints

---
*Auto-generated from Component Fabric. Card: `learnings-data.yaml`*
*Last verified: 2026-02-20*
