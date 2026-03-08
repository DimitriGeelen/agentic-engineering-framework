# learnings-data

> Persistent store of all project learnings. Read by web UI and audit. Written by add-learning command.

**Type:** data | **Subsystem:** learnings-pipeline | **Location:** `.context/project/learnings.yaml`

**Tags:** `learning`, `memory`, `project-memory`, `yaml`

## What It Does

Project Memory - Learnings
Lessons learned from completed tasks.
Used by agents to improve future work.

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `C-002` | writes_by |
| `C-004` | read_by |
| `C-003` | read_by |

## Related

### Tasks
- T-206: Fix add-learning YAML indentation + ID bug
- T-277: First deployment — Watchtower to Ring20 production
- T-278: Harvest deployment learnings — templates to learnings.yaml
- T-344: Interactive auto-init dialogue with directory and provider selection
- T-348: Fix update-task.sh sed failing on macOS BSD sed

---
*Auto-generated from Component Fabric. Card: `learnings-data.yaml`*
*Last verified: 2026-02-20*
