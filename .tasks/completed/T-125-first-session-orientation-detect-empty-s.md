---
id: T-125
name: "First-session orientation: detect empty state, guide new users"
description: >
  Addresses O-001, O-004. Add first-session detection to context.sh init and resume.sh
  quick.
status: work-completed
workflow_type: build
horizon:
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T20:02:41Z
last_update: '2026-08-16T22:24:27Z'
date_finished: 2026-02-17T20:25:07Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
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
  - ts: '2026-08-16T22:24:27Z'
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

# T-125: First-session orientation: detect empty state, guide new users

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T20:02:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-125-first-session-orientation-detect-empty-s.md
- **Context:** Initial task creation

### 2026-02-17T20:25:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-17T20:25:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** First-session detection

## Reviewer Verdict (v1.5)

- **Scan ID:** R-78d5cc96
- **Timestamp:** 2026-06-02T14:56:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
