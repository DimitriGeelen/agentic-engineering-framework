---
id: T-555
name: "Reject template placeholder task names in create-task.sh"
description: >
  Validate that --name is not a template placeholder (task name, Task Name, name,
  description, etc.) before creating task file. Reject with actionable error. Trivial
  string check. Origin: T-549 OpenClaw eval — agent created T-013 with name 'task
  name'.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-23T16:20:19Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-03-24T11:30:15Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 1
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=1 
      (body:error-msg-improved); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-555: Reject template placeholder task names in create-task.sh

## Context

Agent created T-013 with name "task name" during T-549 OpenClaw eval. Trivial validation missing in create-task.sh.

## Acceptance Criteria

### Agent
- [x] create-task.sh rejects placeholder names (case-insensitive: "task name", "name", "description", "First criterion", etc.)
- [x] Rejection prints actionable error with example
- [x] Valid names still work
- [x] Vendored copy synced

## Verification

# Placeholder validation exists in create-task.sh
grep -q "template placeholder" agents/task-create/create-task.sh

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

### 2026-03-23T16:20:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-555-reject-template-placeholder-task-names-i.md
- **Context:** Initial task creation

### 2026-03-24T11:28:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T11:30:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-14b5c70f
- **Timestamp:** 2026-06-02T15:03:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
