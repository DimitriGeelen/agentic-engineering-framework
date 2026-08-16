---
id: T-152
name: "enhance task manager for human"
description: >
  OK, I want to enhance the manual task management. So now I've got very little to
  change the status from capture team progress issues and moved it back and forth.
  So I want to have a manual ability to change what the status is. Furthermore, the
  later now or horizon values I cannot set in the task, so that would be quite beneficial
  I would say. also when a task is submitted by a human user refresh the view so it
  show up

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
related_tasks: []
created: 2026-02-18T12:07:22Z
last_update: '2026-08-16T22:24:35Z'
date_finished: 2026-02-18T12:39:43Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
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
  - ts: '2026-08-16T22:24:35Z'
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

# T-152: enhance task manager for human

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

- [x] Status can be changed from any view (board, list, detail)
- [x] Horizon (now/next/later) can be set on create and changed from any view
- [x] Task list auto-refreshes after creating a new task

## Verification

grep -q 'inline-horizon-select' web/templates/tasks.html
grep -q '/api/task/.*/horizon' web/blueprints/tasks.py
grep -q 'create-task-form' web/templates/tasks.html
python3 -c "import web.blueprints.tasks"

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

### 2026-02-18T12:07:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-152-enhance-task-manager-for-human.md
- **Context:** Initial task creation

### 2026-02-18T12:33:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-18T12:39:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-46707e92
- **Timestamp:** 2026-06-02T14:58:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
