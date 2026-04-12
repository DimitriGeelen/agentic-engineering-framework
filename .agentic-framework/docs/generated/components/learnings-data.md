# learnings-data

> Persistent store of all project learnings. Read by web UI and audit. Written by add-learning command.

**Type:** data | **Subsystem:** learnings-pipeline | **Location:** `.context/project/learnings.yaml`

**Tags:** `learning`, `memory`, `project-memory`, `yaml`

## What It Does

Project Learnings - Knowledge gained during development
Added via: fw context add-learning "description" --task T-XXX

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `C-002` | writes_by |
| `C-004` | read_by |
| `C-003` | read_by |

## Related

### Tasks
- T-937: Commit pending handover checkpoints

---
*Auto-generated from Component Fabric. Card: `learnings-data.yaml`*
*Last verified: 2026-02-20*
