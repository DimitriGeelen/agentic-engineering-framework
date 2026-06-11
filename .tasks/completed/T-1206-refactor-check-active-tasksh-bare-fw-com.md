---
id: T-1206
name: "Refactor check-active-task.sh bare fw commands to use _emit_user_command (T-1146
  GO)"
description: >
  Refactor check-active-task.sh bare fw commands to use _emit_user_command (T-1146
  GO)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/check-active-task.sh, 
      tests/lint/no-bare-fw-in-gate-scripts.bats]
related_tasks: []
created: 2026-04-13T08:27:51Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-13T08:30:21Z
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
---

# T-1206: Refactor check-active-task.sh bare fw commands to use _emit_user_command (T-1146 GO)

## Context

check-active-task.sh is the most frequently triggered gate (fires on every Write/Edit/Bash). Has 15 bare
`fw` command sites in block messages. Part of T-1146 GO (command amnesia remediation).

## Acceptance Criteria

### Agent
- [x] All bare `fw` commands replaced with `_emit_user_command()` or `_fw_cmd()`
- [x] Invariant test extended for check-active-task.sh

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

### 2026-04-13T08:27:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1206-refactor-check-active-tasksh-bare-fw-com.md
- **Context:** Initial task creation

### 2026-04-13T08:30:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4dc61592
- **Timestamp:** 2026-06-02T14:55:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
