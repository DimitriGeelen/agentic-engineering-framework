---
id: T-076
name: Fix fw work-on to prompt for description
description: >
  fw work-on creates tasks with boilerplate description 'Created via fw work-on'.
  This caused 5 SKELETON tasks (T-060,T-068-T-071). Fix: add --description flag passthrough
  or interactive prompt when description not provided. Located in bin/fw work-on command
  handler which calls create-task.sh. See docs/reports/2026-02-15-context-memory-audit.md
  Section 1 root causes.
status: work-completed
workflow_type: build
owner: agent
created: 2026-02-15T16:57:58Z
last_update: '2026-08-16T22:24:18Z'
date_finished: 2026-02-16T19:40:18Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-076: Fix fw work-on to prompt for description

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-15T16:57:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-076-fix-fw-work-on-to-prompt-for-description.md
- **Context:** Initial task creation

### 2026-02-16T19:36:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-16T19:40:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5e86d0a7
- **Timestamp:** 2026-06-02T14:54:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
