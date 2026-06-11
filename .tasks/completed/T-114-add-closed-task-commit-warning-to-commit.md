---
id: T-114
name: Add closed task commit warning to commit-msg hook
description: >
  commit-msg hook currently only validates task reference format (T-XXX pattern).
  Add check: if referenced task ID exists in .tasks/completed/, print warning 'Task
  T-XXX is closed. Consider creating a new task or reopening.' Tier 1 warning (does
  not block). Ref: T-112 forensic analysis, L-034, FP-006, D-022, docs/reports/2026-02-17-premature-task-closure-analysis.md
status: work-completed
workflow_type: build
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T13:37:06Z
last_update: '2026-06-11T22:23:40Z'
date_finished: 2026-02-17T14:39:22Z
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
---

# T-114: Add closed task commit warning to commit-msg hook

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T13:37:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-114-add-closed-task-commit-warning-to-commit.md
- **Context:** Initial task creation

### 2026-02-17T14:38:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-17T14:39:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-82ee246e
- **Timestamp:** 2026-06-02T14:55:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
