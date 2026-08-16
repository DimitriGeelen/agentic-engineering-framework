---
id: T-1207
name: "Refactor remaining context agent scripts bare fw commands (T-1146 GO)"
description: >
  Refactor remaining context agent scripts bare fw commands (T-1146 GO)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-007, agents/context/check-agent-dispatch.sh, C-008, 
      agents/context/check-project-boundary.sh, 
      tests/lint/no-bare-fw-in-gate-scripts.bats]
related_tasks: []
created: 2026-04-13T08:30:29Z
last_update: '2026-08-16T22:24:25Z'
date_finished: 2026-04-13T08:33:33Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1207: Refactor remaining context agent scripts bare fw commands (T-1146 GO)

## Context

Remaining bare `fw` commands in checkpoint.sh (5), budget-gate.sh (4), check-agent-dispatch.sh (3),
check-project-boundary.sh (2). Part of T-1146 GO (command amnesia remediation).

## Acceptance Criteria

### Agent
- [x] checkpoint.sh bare `fw` commands replaced
- [x] budget-gate.sh bare `fw` commands replaced
- [x] check-agent-dispatch.sh bare `fw` commands replaced
- [x] check-project-boundary.sh bare `fw` commands replaced
- [x] Invariant test extended

## Verification

bats tests/lint/no-bare-fw-in-gate-scripts.bats

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

### 2026-04-13T08:30:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1207-refactor-remaining-context-agent-scripts.md
- **Context:** Initial task creation

### 2026-04-13T08:33:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fb3a811b
- **Timestamp:** 2026-06-02T14:55:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
