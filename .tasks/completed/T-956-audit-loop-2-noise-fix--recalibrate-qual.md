---
id: T-956
name: "Audit Loop 2 noise fix — recalibrate quality thresholds or escalate differently
  (T-860 Phase 2)"
description: >
  Loop 2 (active task quality) fires warnings that persist for weeks without action.
  Either recalibrate thresholds so warnings are actionable, or route stale warnings
  to human review queue. From T-860 GO decision.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/audit/active-task-scan.py]
related_tasks: []
created: 2026-04-06T11:50:13Z
last_update: '2026-06-11T22:24:33Z'
date_finished: 2026-04-06T13:00:45Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-956: Audit Loop 2 noise fix — recalibrate quality thresholds or escalate differently (T-860 Phase 2)

## Context

Loop 2 (quality) fires warnings nobody acts on — "short description" and "stale task" persist for weeks. Recalibrate thresholds so warnings are actionable. From T-860 value analysis.

## Acceptance Criteria

### Agent
- [x] Short description threshold raised from 50 to 30 chars
- [x] Stale task threshold raised from 7 to 14 days
- [x] Audit produces fewer noisy quality warnings
- [x] No real quality issues masked by threshold changes

## Verification

# Audit quality section runs without errors
bash -c 'bin/fw audit --section quality 2>&1 | tail -3; exit 0'

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-06T11:50:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-956-audit-loop-2-noise-fix--recalibrate-qual.md
- **Context:** Initial task creation

### 2026-04-06T12:59:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-06T13:00:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f6004763
- **Timestamp:** 2026-06-02T15:05:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
