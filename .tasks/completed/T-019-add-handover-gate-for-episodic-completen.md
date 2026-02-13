---
id: T-019
name: Add handover gate for episodic completeness
description: >
  Handover agent should check before generating: (1) Any tasks completed since last handover? (2) Do they all have episodic files? (3) Are those episodics enriched (not pending)? Warn if gaps exist. This prevents context loss at session boundaries.
status: work-completed
workflow_type: build
owner: human
priority: medium
tags: [handover, D2, P-002]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T21:21:44Z
last_update: 2026-02-13T22:04:00Z
date_finished: null
---

# T-019: Add handover gate for episodic completeness

## Design Record

**Approach:** Add a check between "gather state" and "create document" in handover.sh. The check finds recently completed tasks (modified in last 24 hours), verifies each has an episodic file with enrichment_status: complete. Warns if gaps exist but doesn't block — per FP-003, warnings are appropriate for older tasks that predate the system.

## Specification Record

Acceptance criteria:
- [x] Check finds tasks completed since last handover (last 24h)
- [x] Verifies each has episodic file
- [x] Verifies episodic is enriched (not pending)
- [x] Warns clearly if gaps exist
- [x] Shows guidance on how to fix (generate + enrich)
- [x] Passes silently when all episodics are complete

## Test Files

- Run `./agents/handover/handover.sh` — should show episodic check status

## Updates

### 2026-02-13T21:21:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-019-add-handover-gate-for-episodic-completen.md
- **Context:** Initial task creation

### 2026-02-13T22:04:00Z — work-completed [claude-code]
- **Action:** Added episodic completeness gate to handover.sh
- **Output:**
  - Step 1.5: EPISODIC COMPLETENESS GATE between gather state and create document
  - Checks recently modified completed tasks for episodic existence and enrichment
  - Shows warnings with fix guidance, or success message if all complete
- **Context:** Closes the enforcement loop at session boundaries (per T-018 handover)
