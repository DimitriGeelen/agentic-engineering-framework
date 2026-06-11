---
id: T-019
name: Add handover gate for episodic completeness
description: >
  Handover agent should check before generating: (1) Any tasks completed since last
  handover? (2) Do they all have episodic files? (3) Are those episodics enriched
  (not pending)? Warn if gaps exist. This prevents context loss at session boundaries.
status: work-completed
workflow_type: build
owner: human
priority: medium
tags: [handover, D2, P-002]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T21:21:44Z
last_update: '2026-06-11T22:23:35Z'
date_finished: 2026-02-13T22:04:35Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3bb3d0f5
- **Timestamp:** 2026-06-02T14:54:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
