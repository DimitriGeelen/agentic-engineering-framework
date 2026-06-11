---
id: T-051
name: Simplify task lifecycle
description: >
  G-002 decided-simplify: Remove refined/blocked statuses never used in 50 tasks.
  Add transition validation to update-task.sh. Actual lifecycle: captured -> started-work
  <-> issues -> work-completed.
status: work-completed
workflow_type: refactor
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T12:48:44Z
last_update: '2026-06-11T22:23:36Z'
date_finished: 2026-02-14T13:05:33Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:36Z'
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
---

# T-051: Simplify task lifecycle

## Design Record

[Architecture decisions, approach rationale — inline or link to artifact]

## Specification Record

[Requirements, acceptance criteria — inline or link to artifact]

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-14T12:48:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-051-simplify-task-lifecycle.md
- **Context:** Initial task creation

### 2026-02-14T12:51:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-02-14T13:05:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Lifecycle simplified, transitions validated

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4554803f
- **Timestamp:** 2026-06-02T14:54:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
