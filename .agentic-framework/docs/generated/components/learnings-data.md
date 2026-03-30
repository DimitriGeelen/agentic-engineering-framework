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
- T-495: Path isolation — eliminate hardcoded absolute paths from all committed files
- T-546: Continue fixing TermLink release builds
- T-614: TermLink consumer project governance bypass investigation — Tier 0 bypass, taskless work, structural regression analysis

---
*Auto-generated from Component Fabric. Card: `learnings-data.yaml`*
*Last verified: 2026-02-20*
