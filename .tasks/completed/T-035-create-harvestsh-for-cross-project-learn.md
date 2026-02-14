---
id: T-035
name: Create harvest.sh for cross-project learning
description: >
  Pull learnings patterns decisions from project back to framework with provenance tracking and graduation pipeline
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: [cross-project, learning, harvest]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T23:45:28Z
last_update: 2026-02-14T09:01:23Z
date_finished: 2026-02-14T09:01:23Z
---

# T-035: Create harvest.sh for cross-project learning

## Design Record

**Architecture:** `lib/harvest.sh` sourced by fw when `fw harvest` is invoked.

**How it works:**
1. Reads project `.context/project/{patterns,learnings,decisions}.yaml`
2. Compares against framework `.context/project/` files
3. Reports NEW (unique to project) and DUP (already in framework)
4. On non-dry-run, appends new items with provenance tracking
5. Decisions are reported but not auto-promoted (project-specific)

**Graduation pipeline:** (designed, not yet enforced)
- 1 project = local (stays in project)
- 2+ projects = candidate (proposed for framework)
- 3+ projects = practice (promoted)

**Key decisions:**
- String-matching deduplication (grep -F) — simple, effective for exact matches
- Provenance tracking via `harvested_from` and `harvest_date` fields
- Decisions not auto-promoted — they're project-specific by nature
- Harvest log at `.context/harvest.log` for audit trail

## Specification Record

**Acceptance Criteria:**
- [x] `fw harvest --dry-run` shows what would be harvested
- [x] Detects new patterns, learnings, decisions
- [x] Correctly identifies duplicates
- [x] Refuses to harvest from framework itself
- [x] Appends with provenance when not dry-run
- [x] `--verbose` shows duplicates explicitly
- [x] Harvest log maintained

## Updates

### 2026-02-13T23:45:28Z — task-created [task-create-agent]

### 2026-02-14T09:01:23Z — build-completed [claude-code]
- **Action:** Built lib/harvest.sh and wired into fw CLI
- **Output:** lib/harvest.sh, updated bin/fw
- **Tests:** Created test project with mixed new/duplicate learnings and patterns. Dry-run correctly identified 1 new pattern, 1 new learning, 2 duplicates.
