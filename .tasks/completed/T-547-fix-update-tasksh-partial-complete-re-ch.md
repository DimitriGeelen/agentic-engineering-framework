---
id: T-547
name: "Fix update-task.sh partial-complete re-check for tasks with no ACs"
description: >
  Fix update-task.sh partial-complete re-check for tasks with no ACs

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-23T11:07:03Z
last_update: 2026-03-23T11:08:58Z
date_finished: 2026-03-23T11:08:58Z
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
