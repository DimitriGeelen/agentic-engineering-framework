---
id: T-408
name: "Remediate audit warnings: fabric edges, uncommitted changes, bugfix-learning,
  T-203 lifecycle"
description: >
  Remediate audit warnings: fabric edges, uncommitted changes, bugfix-learning, T-203
  lifecycle

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [audit, housekeeping]
components: []
related_tasks: []
created: 2026-03-10T16:59:57Z
last_update: '2026-06-11T22:24:20Z'
date_finished: 2026-03-10T17:07:23Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-408: Remediate audit warnings: fabric edges, uncommitted changes, bugfix-learning, T-203 lifecycle

## Context

Audit reported 4 WARN: (1) 18/136 fabric cards have no edges, (2) uncommitted changes, (3) bugfix-learning 38% < 40% target, (4) T-203 lifecycle anomaly (0min scratch test).

## Acceptance Criteria

### Agent
- [x] Bugfix-learning coverage >= 40% (added L-096 for T-407, L-097 for T-406)
- [x] T-203 reclassified from build to test (correct workflow_type for scratch test)
- [x] Fabric cards enriched with dependency edges (sub-agent dispatched)
- [x] All changes committed (clears uncommitted warning)

## Verification

grep -q "task: T-407" .context/project/learnings.yaml
grep -q "task: T-406" .context/project/learnings.yaml
grep -q "workflow_type: test" .tasks/completed/T-203-scratch-test--partial-complete-verificat.md

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

### 2026-03-10T16:59:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-408-remediate-audit-warnings-fabric-edges-un.md
- **Context:** Initial task creation

### 2026-03-10T17:07:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-69ba1383
- **Timestamp:** 2026-06-02T15:02:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
