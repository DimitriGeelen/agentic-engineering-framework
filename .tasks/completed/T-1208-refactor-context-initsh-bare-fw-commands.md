---
id: T-1208
name: "Refactor context init.sh bare fw commands to use _fw_cmd (T-1146 GO)"
description: >
  Refactor context init.sh bare fw commands to use _fw_cmd (T-1146 GO)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/lib/init.sh, 
      tests/lint/no-bare-fw-in-gate-scripts.bats]
related_tasks: []
created: 2026-04-13T08:41:07Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-13T08:43:09Z
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

# T-1208: Refactor context init.sh bare fw commands to use _fw_cmd (T-1146 GO)

## Context

agents/context/lib/init.sh is the context init welcome message — first thing agents see. Has 7 bare
`fw` command sites. Part of T-1146 GO (command amnesia remediation).

## Acceptance Criteria

### Agent
- [x] All bare `fw` commands in init.sh replaced with `_fw_cmd()`
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

### 2026-04-13T08:41:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1208-refactor-context-initsh-bare-fw-commands.md
- **Context:** Initial task creation

### 2026-04-13T08:43:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4afcecf6
- **Timestamp:** 2026-06-02T14:55:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
