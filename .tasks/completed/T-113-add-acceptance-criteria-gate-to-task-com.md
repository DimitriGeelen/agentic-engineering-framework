---
id: T-113
name: Add acceptance criteria gate to task completion
description: >
  update-task.sh currently sets work-completed unconditionally. Add validation: (1)
  task template includes Acceptance Criteria section with checkboxes, (2) update-task.sh
  parses AC checkboxes and refuses work-completed unless all checked or --force bypass
  with reason logged. Ref: T-112 forensic analysis, L-034, FP-006, D-022, docs/reports/2026-02-17-premature-task-closure-analysis.md
status: work-completed
workflow_type: build
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T13:37:01Z
last_update: '2026-08-16T22:24:23Z'
date_finished: 2026-02-17T14:42:54Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-113: Add acceptance criteria gate to task completion

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T13:37:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-113-add-acceptance-criteria-gate-to-task-com.md
- **Context:** Initial task creation

### 2026-02-17T14:41:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-17T14:42:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-eba50a90
- **Timestamp:** 2026-06-02T14:55:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
