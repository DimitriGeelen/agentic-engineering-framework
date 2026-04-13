---
id: T-1240
name: "Fix Watchtower tasks page string sort — T-1000+ tasks hidden between T-1xx"
description: >
  Fix Watchtower tasks page string sort — T-1000+ tasks hidden between T-1xx

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-13T19:27:08Z
last_update: 2026-04-13T19:41:55Z
date_finished: 2026-04-13T19:41:55Z
---

# T-1240: Fix Watchtower tasks page string sort — T-1000+ tasks hidden between T-1xx

## Context

Task IDs sorted as strings — T-1000 appears between T-100 and T-101 instead of after T-999.
9 instances across web/ need fixing. Related: T-675 (regex fix for 3+ digit IDs).

## Acceptance Criteria

### Agent
- [x] Add `task_id_sort_key()` helper to `web/shared.py` for numeric task ID sorting
- [x] Fix all 9 string-sort instances in web/ to use numeric sort
- [x] /tasks page shows T-1000+ after T-999 (not interleaved with T-1xx)
- [x] Web tests pass (142/142)

### Human
- [ ] [RUBBER-STAMP] Tasks page shows T-1000+ tasks at bottom when sorted by ID
  **Steps:**
  1. Open http://localhost:3000/tasks?view=list&sort=id
  2. Scroll to bottom of list
  **Expected:** T-1239 appears after T-999, not hidden between T-100-T-199
  **If not:** Check browser console for errors, report which task ID range is visible at bottom

## Verification

python3 -c "from web.shared import task_id_sort_key; assert task_id_sort_key('T-1000') > task_id_sort_key('T-999')"
python3 -c "from web.shared import task_id_sort_key; assert task_id_sort_key('T-100') < task_id_sort_key('T-1000')"
curl -sf http://localhost:3000/tasks?view=list | grep -q 'T-1239'

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

### 2026-04-13T19:27:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1240-fix-watchtower-tasks-page-string-sort--t.md
- **Context:** Initial task creation

### 2026-04-13T19:41:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
