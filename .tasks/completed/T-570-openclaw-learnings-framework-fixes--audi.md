---
id: T-570
name: "OpenClaw learnings: framework fixes — audit baseline marker, commit cadence hook"
description: >
  Two framework improvement items from the eval. (1) Git traceability audit on ingested repos — audit counted all 21557 upstream OpenClaw commits at 0 percent traceability. Need a baseline commit marker so audit only counts post-framework-init commits. (2) Commit cadence warning hook — PostToolUse hook warning after N edits without commit. No structural enforcement exists for minimum commit frequency. Research approaches, write findings. Review with human.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T17:18:11Z
last_update: 2026-03-25T09:55:57Z
date_finished: 2026-03-25T09:55:57Z
---

# T-570: OpenClaw learnings: framework fixes — audit baseline marker, commit cadence hook

## Problem Statement

Two framework gaps discovered during T-549 OpenClaw evaluation:
1. Git traceability audit counts ALL upstream commits (0% traceability on ingested repos)
2. No structural enforcement for commit frequency — agents make many edits without committing

## Status: SUPERSEDED

Both items were independently built before this inception started:

1. **Audit baseline marker** → Built in **T-590** (committed `d8177dc`)
   - `fw traceability baseline` sets HEAD SHA as baseline
   - Audit uses `${baseline}..HEAD` range for post-import commits only

2. **Commit cadence hook** → Built in **T-591** (committed `70e40fb`)
   - PostToolUse hook on Write|Edit counts edits via `.edit-counter`
   - Warns at 10 edits, strong warns at 20, reset via post-commit hook

No further exploration needed.

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (both items already built)
- [x] Recommendation written — superseded by T-590 and T-591

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: SUPERSEDED

**Rationale**: Both deliverables (audit baseline marker, commit cadence hook) were independently built in T-590 and T-591 before this inception started. No further exploration needed.

**Date**: 2026-03-25T10:00:00Z

## Updates

### 2026-03-25T09:54:55Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-25T10:00:00Z — superseded [agent]
- **Action:** Both items already built in T-590 (baseline) and T-591 (commit cadence)
- **Decision:** SUPERSEDED — no exploration needed

### 2026-03-25T09:55:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Superseded by T-590 and T-591

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8ae3d214
- **Timestamp:** 2026-06-02T15:03:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
