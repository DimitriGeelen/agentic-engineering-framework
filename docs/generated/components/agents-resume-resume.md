# resume

> Resume Agent - Post-compaction recovery and state synchronization

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/resume/resume.sh`

## What It Does

Resume Agent - Post-compaction recovery and state synchronization
Synthesizes current state from handover, working memory, git, and tasks

### Framework Reference

**Location:** `agents/resume/`

**When to use:** After context compaction, returning from breaks, or when feeling lost about current state.

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |

## Related

### Tasks
- T-185: Add inception research audit check and resume docs/reports scanning (T-178 GO)
- T-241: Wire discovery findings into session-start and Watchtower
- T-348: Fix update-task.sh sed failing on macOS BSD sed

---
*Auto-generated from Component Fabric. Card: `agents-resume-resume.yaml`*
*Last verified: 2026-02-20*
