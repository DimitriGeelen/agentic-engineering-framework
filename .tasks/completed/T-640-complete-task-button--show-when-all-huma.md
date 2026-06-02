---
id: T-640
name: "\"Complete Task\" button — show when all Human ACs checked, auto-complete via Watchtower"
description: >
  "Complete Task" button — show when all Human ACs checked, auto-complete via Watchtower

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [web/blueprints/tasks.py, web/templates/task_detail.html]
related_tasks: []
created: 2026-03-27T11:32:46Z
last_update: 2026-04-06T22:29:19Z
date_finished: 2026-03-27T11:36:45Z
---

# T-640: "Complete Task" button — show when all Human ACs checked, auto-complete via Watchtower

## Context

T-636 Phase 1, task 3. When all ACs are checked on a task detail page, show a "Complete Task" button that calls `fw task update --status work-completed --force`. Design: docs/reports/fw-agent-t636-04-ac-checkboxes.md (Gap 1 + Gap 2).

## Acceptance Criteria

### Agent
- [x] "Complete Task" button appears on task detail when all ACs checked
- [x] Button passes --force flag (human sovereignty — browser click = human action)
- [x] Button hidden when task already work-completed
- [x] /api/task/<id>/complete endpoint exists and calls fw task update

### Human
- [x] [RUBBER-STAMP] Complete Task button works end-to-end
  **Steps:**
  1. Open http://192.168.10.107:3000/approvals
  2. Find a task with all Human ACs checked (or check them all)
  3. Click the task link to go to task detail
  4. Verify "Complete Task" button appears
  5. Click it and verify task moves to completed
  **Expected:** Task status changes to work-completed, button disappears
  **If not:** Note error message in browser

## Verification

grep -q 'complete' web/blueprints/tasks.py
grep -q 'complete-button' web/templates/task_detail.html

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

### 2026-03-27T11:32:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-640-complete-task-button--show-when-all-huma.md
- **Context:** Initial task creation

### 2026-03-27T11:36:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3e3bb6a4
- **Timestamp:** 2026-06-02T15:04:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
