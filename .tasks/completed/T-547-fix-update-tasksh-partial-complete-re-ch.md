---
id: T-547
name: "Fix update-task.sh partial-complete re-check for tasks with no ACs"
description: >
  Fix update-task.sh partial-complete re-check for tasks with no ACs

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-23T11:07:03Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-03-23T11:08:58Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
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

# T-547: Fix update-task.sh partial-complete re-check for tasks with no ACs

## Context

When a task is `work-completed` in `active/` (partial-complete) and has 0 total ACs (template comments only, no checkboxes), re-running `fw task update T-XXX --status work-completed` blocks with "Check human ACs" because the condition requires `ALL_TOTAL > 0`.

## Acceptance Criteria

### Agent
- [x] `update-task.sh` re-check allows completion when ALL_TOTAL=0 and ALL_UNCHECKED=0
- [x] Tasks T-522 through T-529 can be completed after the fix

## Verification

# The fix: condition allows 0/0 (no ACs) to pass
grep -q 'ALL_UNCHECKED.*-eq 0' agents/task-create/update-task.sh

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

### 2026-03-23T11:07:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-547-fix-update-tasksh-partial-complete-re-ch.md
- **Context:** Initial task creation

### 2026-03-23T11:08:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ef0a8e36
- **Timestamp:** 2026-06-02T15:03:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
