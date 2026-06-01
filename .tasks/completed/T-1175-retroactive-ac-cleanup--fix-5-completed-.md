---
id: T-1175
name: "Retroactive AC cleanup — fix 5 completed tasks with placeholder ACs"
description: >
  Retroactive AC cleanup — fix 5 completed tasks with placeholder ACs

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T17:04:45Z
last_update: 2026-04-12T17:06:37Z
date_finished: 2026-04-12T17:06:37Z
---

# T-1175: Retroactive AC cleanup — fix 5 completed tasks with placeholder ACs

## Context

5 completed tasks have `[First criterion]` placeholder ACs: T-169, T-437, T-444, T-452, T-453. Replace with real ACs reflecting actual work done.

## Acceptance Criteria

### Agent
- [x] All 5 tasks have real ACs (no placeholders remaining)
- [x] Zero `[First criterion]` matches in completed tasks (excluding T-216 which mentions the pattern in context, T-1082/T-1174 which are about fixing this, and T-1175 itself)

## Verification

# No placeholder ACs in completed tasks (excluding meta-tasks about this pattern)
bash -c 'count=$(grep -rl "\[First criterion\]" .tasks/completed/ 2>/dev/null | grep -v "T-216\|T-1082\|T-1174\|T-1175" | wc -l); [ "$count" -eq 0 ]'

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

### 2026-04-12T17:04:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1175-retroactive-ac-cleanup--fix-5-completed-.md
- **Context:** Initial task creation

### 2026-04-12T17:06:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
