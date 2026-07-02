---
id: T-143
name: "Fix create-task.sh: quote name field to prevent YAML errors from colons"
description: >
  Fix create-task.sh: quote name field to prevent YAML errors from colons

status: work-completed
workflow_type: build
owner: agent
horizon: null
related_tasks: []
created: 2026-02-18T09:14:54Z
last_update: '2026-06-11T22:23:48Z'
date_finished: 2026-02-18T09:15:46Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
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

# T-143: Fix create-task.sh: quote name field to prevent YAML errors from colons

## Context

T-124 cycle 4: 16/23 sprechloop tasks had unquoted colons in `name:` field (e.g. `name: Spike: own pipeline`), causing YAML parse errors. Watchtower showed only 7 tasks instead of 23.

## Acceptance Criteria

- [x] create-task.sh quotes name field in both template paths (inception + default)
- [x] Sprechloop tasks with colons fixed (16 files)
- [x] Test added: task with colon in name produces valid YAML (test 10, 22/22 pass)

## Verification

tests/test-knowledge-capture.sh

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

### 2026-02-18T09:14:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-143-fix-create-tasksh-quote-name-field-to-pr.md
- **Context:** Initial task creation

### 2026-02-18T09:15:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b243e081
- **Timestamp:** 2026-06-02T14:57:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
