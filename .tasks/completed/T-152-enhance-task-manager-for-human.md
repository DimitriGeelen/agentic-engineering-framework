---
id: T-152
name: "enhance task manager for human"
description: >
  OK, I want to enhance the manual task management. So now I've got very little to change the status from capture team progress issues and moved it back and forth. So I want to have a manual ability to change what the status is. Furthermore, the later now or horizon values I cannot set in the task, so that would be quite beneficial I would say. also when a task is submitted by a human user refresh the view so it show up

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
related_tasks: []
created: 2026-02-18T12:07:22Z
last_update: 2026-02-18T12:39:43Z
date_finished: 2026-02-18T12:39:43Z
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
