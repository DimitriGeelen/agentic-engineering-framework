---
id: T-062
name: Add instruction precedence declaration to CLAUDE.md
description: >
  T-061 finding: CLAUDE.md and superpowers plugin both claim absolute authority with
  no resolution. Add explicit precedence section: (1) CLAUDE.md framework rules apply
  FIRST, (2) Skills apply AFTER framework gates satisfied, (3) 'Invoke skills BEFORE
  any response' means AFTER task exists. This is the cheapest fix with highest impact
  — one paragraph that resolves the authority conflict.
status: work-completed
workflow_type: specification
owner: agent
created: 2026-02-15T08:35:06Z
last_update: '2026-08-16T22:24:18Z'
date_finished: 2026-02-15T08:38:27Z
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

# T-062: Add instruction precedence declaration to CLAUDE.md

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-15T08:35:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-062-add-instruction-precedence-declaration-t.md
- **Context:** Initial task creation

### 2026-02-15T08:37:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** owner: human → agent

### 2026-02-15T08:38:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-70e3b54a
- **Timestamp:** 2026-06-02T14:54:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
