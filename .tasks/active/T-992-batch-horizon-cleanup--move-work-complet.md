---
id: T-992
name: "Batch horizon cleanup — move work-completed now tasks to next"
description: >
  Batch horizon cleanup — move work-completed now tasks to next

status: issues
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T09:51:49Z
last_update: 2026-04-07T09:52:28Z
date_finished: null
---

# T-992: Batch horizon cleanup — move work-completed now tasks to next

## Context

Tasks with `work-completed` status and `horizon: now` are cluttering the immediate work queue. They only need human review, not agent work. Moving to `horizon: next` keeps "now" clean for actionable items.

## Acceptance Criteria

### Agent
- [ ] All work-completed + horizon:now tasks moved to horizon:next
- [ ] No tasks that genuinely need agent work are affected
- [ ] fw doctor shows reduced stale task count

## Verification

# Verify no work-completed tasks remain at horizon:now
cd /opt/999-Agentic-Engineering-Framework && test $(grep -l 'status: work-completed' .tasks/active/T-*.md 2>/dev/null | xargs grep -l 'horizon: now' 2>/dev/null | wc -l) -eq 0

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

### 2026-04-07T09:51:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-992-batch-horizon-cleanup--move-work-complet.md
- **Context:** Initial task creation

### 2026-04-07T09:52:28Z — status-update [task-update-agent]
- **Change:** status: started-work → issues
- **Reason:** User vetoed batch horizon move
