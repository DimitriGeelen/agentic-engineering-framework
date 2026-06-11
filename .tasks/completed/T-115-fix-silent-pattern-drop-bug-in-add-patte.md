---
id: T-115
name: Fix silent pattern drop bug in add-pattern command
description: >
  context.sh add-pattern silently drops entries when appending to non-empty sections.
  Root cause: awk script uses prev~section which never matches (prev is last data
  line, not section header). Fix: track in_section state. Found during T-112 investigation
  when FP-006 was 'added' but missing from file. Ref: L-034, FP-006.
status: work-completed
workflow_type: build
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T13:54:04Z
last_update: '2026-06-11T22:23:41Z'
date_finished: 2026-02-17T13:54:45Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-115: Fix silent pattern drop bug in add-pattern command

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T13:54:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-115-fix-silent-pattern-drop-bug-in-add-patte.md
- **Context:** Initial task creation

### 2026-02-17T13:54:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-484b7947
- **Timestamp:** 2026-06-02T14:55:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
