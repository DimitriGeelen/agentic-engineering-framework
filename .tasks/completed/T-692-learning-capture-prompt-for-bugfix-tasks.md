---
id: T-692
name: "Learning capture prompt for bugfix tasks — structural nudge in update-task.sh when completing fix tasks without a learning entry"
description: >
  Learning capture prompt for bugfix tasks — structural nudge in update-task.sh when completing fix tasks without a learning entry

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/task-create/update-task.sh]
related_tasks: []
created: 2026-03-28T23:47:17Z
last_update: 2026-03-28T23:49:39Z
date_finished: 2026-03-28T23:49:39Z
---

# T-692: Learning capture prompt for bugfix tasks — structural nudge in update-task.sh when completing fix tasks without a learning entry

## Context

G-016: 72% of bugfix tasks produce zero learning entries. The Bug-Fix Learning Checkpoint practice in CLAUDE.md is behavioral (agent self-governs). This adds a structural nudge: when completing a task whose name contains "fix", check if any learning references that task ID. If not, emit a prompt.

## Acceptance Criteria

### Agent
- [x] update-task.sh checks for "fix" in task name on work-completed
- [x] Checks learnings.yaml for entries referencing the task ID
- [x] Emits a visible prompt when no learning exists for a fix task
- [x] Prompt is advisory (non-blocking) — does not prevent completion
- [x] Does not fire for non-fix tasks

## Verification

grep -q 'Learning capture check' agents/task-create/update-task.sh
grep -q 'learnings.yaml' agents/task-create/update-task.sh

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

### 2026-03-28T23:47:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-692-learning-capture-prompt-for-bugfix-tasks.md
- **Context:** Initial task creation

### 2026-03-28T23:49:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
