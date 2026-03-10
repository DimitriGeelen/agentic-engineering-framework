---
id: T-399
name: "Task board: owner/horizon filters, tag filter, search within board"
description: >
  Add owner and horizon filters to board view, tag-based filtering, and local search within task board. Currently only status/type/component filters exist.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-10T09:43:58Z
last_update: 2026-03-10T10:37:49Z
date_finished: null
---

# T-399: Task board: owner/horizon filters, tag filter, search within board

## Context

Added shared filter bar (search, owner, horizon, tag) to task board and list views. Backend extended with owner, horizon, search filtering in `tasks.py`. Shared bar renders above both board and list views with htmx for instant filtering.

## Acceptance Criteria

### Agent
- [x] Owner filter dropdown with htmx live filtering
- [x] Horizon filter dropdown (now/next/later)
- [x] Tag filter dropdown (populated from task tags)
- [x] Text search input filtering by ID, name, description, tags
- [x] "Clear filters" link appears when any filter is active
- [x] Filters work in both board and list views
- [x] All filter dropdowns include each other in hx-include for composability
- [x] Backend `tasks.py` handles owner, horizon, q parameters

### Human
- [ ] [REVIEW] Filter bar looks clean and works in browser
  **Steps:**
  1. Open http://localhost:3000/tasks in browser
  2. Select "agent" from Owner dropdown — board should show only agent-owned tasks
  3. Select "now" from Horizon — further narrows
  4. Type "mobile" in search — should show only T-400
  5. Click "× Clear filters" — all tasks return
  6. Switch to List view — same filters should appear and work
  **Expected:** Filters compose, results update instantly, clear link resets all
  **If not:** Note which filter doesn't work or breaks the layout

## Verification

# Tasks page renders
curl -sf http://localhost:3000/tasks
# Owner filter works
curl -sf 'http://localhost:3000/tasks?view=board&owner=agent' | grep -q 'kanban-card'
# Horizon filter works
curl -sf 'http://localhost:3000/tasks?view=board&horizon=later' | grep -q 'kanban-card'
# Search filter works
curl -sf 'http://localhost:3000/tasks?view=board&q=mobile' | grep -q 'kanban-card'
# Clear filters link appears
curl -sf 'http://localhost:3000/tasks?view=board&owner=agent' | grep -q 'Clear filters'
# List view renders with filters
curl -sf 'http://localhost:3000/tasks?view=list&owner=human'

## Decisions

None — additive enhancement to existing filter system.

## Updates

### 2026-03-10T09:43:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-399-task-board-ownerhorizon-filters-tag-filt.md
- **Context:** Initial task creation
