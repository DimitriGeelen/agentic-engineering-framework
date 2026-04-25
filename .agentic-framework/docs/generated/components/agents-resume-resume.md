# resume

> Resume Agent - Post-compaction recovery and state synchronization

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/resume/resume.sh`

## What It Does

Resume Agent - Post-compaction recovery and state synchronization
Synthesizes current state from handover, working memory, git, and tasks

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/paths.sh` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `tests/unit/resume.bats` | tested_by |
| `tests/unit/resume.bats` | called_by |

## Related

### Tasks
- T-794: Fix shellcheck SC2155 warnings in resume.sh — split declare and assign
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-resume-resume.yaml`*
*Last verified: 2026-02-20*
