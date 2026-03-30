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
- T-677: Fix fw init hook merge — pre-existing settings.json blocks framework hooks
- T-678: vnx-orchestration deep-dive — ingest, build fabric, analyze architecture and patterns
- T-679: Path C workflow refinement — document TermLink-based external ingestion, redo vnx experiment from scratch, capture learnings for TermLink and framework
- T-693: Fix learning prompt false positive — match task names starting with Fix, not containing fix anywhere
- T-697: Deep-dive: KCP (Knowledge Context Protocol) — Path C codebase ingestion

---
*Auto-generated from Component Fabric. Card: `learnings-data.yaml`*
*Last verified: 2026-02-20*
