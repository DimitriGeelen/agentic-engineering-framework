---
id: T-1197
name: "Fix G-041: Replace hardcoded status selectors in kanban CSS/HTML with dynamic Jinja enum"
description: >
  Fix G-041: Replace hardcoded status selectors in kanban CSS/HTML with dynamic Jinja enum

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-13T06:55:54Z
last_update: 2026-04-13T06:55:54Z
date_finished: null
---

# T-1197: Fix G-041: Replace hardcoded status selectors in kanban CSS/HTML with dynamic Jinja enum

## Context

G-041: tasks.html has 25 hardcoded status references (4 arrays, 9 CSS selectors, 7 column divs). T-1188 fixed Python side. This fixes templates.

## Acceptance Criteria

### Agent
- [x] tasks.html status arrays replaced with Jinja variable from backend
- [x] Kanban columns generated dynamically from status list
- [x] All status arrays use `enum_statuses|default(...)` pattern — no bare hardcoded arrays
- [x] Tasks page renders correctly (17 Playwright tests pass)

## Verification

# No hardcoded status arrays WITHOUT |default guard (bare arrays would lack enum_statuses)
cd /opt/999-Agentic-Engineering-Framework && ! grep "captured.*started-work.*issues.*work-completed" web/templates/tasks.html | grep -qv '|default'
# Tasks page loads with kanban columns
curl -sf http://localhost:3000/tasks | grep -q 'kanban-column'
# enum_statuses passed from backend
grep -q 'enum_statuses' web/blueprints/tasks.py

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

### 2026-04-13T06:55:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1197-fix-g-041-replace-hardcoded-status-selec.md
- **Context:** Initial task creation
