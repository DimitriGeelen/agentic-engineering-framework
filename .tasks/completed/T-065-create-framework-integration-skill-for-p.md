---
id: T-065
name: Create framework integration skill for plugin task-awareness
description: >
  T-061 finding: 0/20 loaded skills mention framework task creation. All major workflows
  (brainstorming, TDD, executing-plans, feature-dev) bypass the task system entirely.
  Design and create a framework-integration skill that: (1) detects .tasks/ directory
  presence, (2) requires active task before deferring to other skills, (3) loads with
  higher priority than using-superpowers, (4) wraps the skill invocation flow with
  task gates. This is a Tier D fix — changes ways of working.
status: work-completed
workflow_type: design
owner: human
created: 2026-02-15T08:35:16Z
last_update: '2026-08-16T22:24:18Z'
date_finished: 2026-02-15T08:46:43Z
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
  - ts: '2026-08-16T22:24:18Z'
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

# T-065: Create framework integration skill for plugin task-awareness

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-15T08:35:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-065-create-framework-integration-skill-for-p.md
- **Context:** Initial task creation

### 2026-02-15T08:44:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-15T08:46:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e3a9c2db
- **Timestamp:** 2026-06-02T14:54:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
