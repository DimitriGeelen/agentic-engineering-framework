---
id: T-183
name: "Productionize web UI inline editing (T-181 follow-up)"
description: >
  Build task from T-181 GO decision. The spike code (name edit, AC checkboxes, description edit) is functional but needs polish: (1) better error feedback on save failures, (2) loading states during API calls, (3) edge case handling for multi-line description editing (folded scalars), (4) status/horizon dropdown editing, (5) tag editing UI. See T-181 episodic and web/blueprints/tasks.py for spike code.

status: started-work
workflow_type: build
owner: human
horizon: next
tags: []
related_tasks: []
created: 2026-02-19T00:02:28Z
last_update: 2026-02-19T00:26:08Z
date_finished: null
---

# T-183: Productionize web UI inline editing (T-181 follow-up)

## Context

Productionize the T-181 spike for inline editing on the web UI. Spike works but lacks error feedback, loading states, and detail page has button-based forms instead of inline dropdowns.

## Acceptance Criteria

- [x] Error feedback: failed saves show visible error toast/message (not silent revert)
- [x] Loading states: saving indicator appears during API calls on all editable fields
- [x] Detail page: status and horizon use inline dropdowns (like kanban/list), not button forms
- [x] Detail page: owner and type editable via inline dropdowns
- [x] All inline edits persist correctly (verified via Playwright round-trip)

## Verification

# Detail page loads with inline dropdowns
curl -sf http://localhost:3000/tasks/T-183 -o /tmp/t183-check.html && grep -q "inline-status-select" /tmp/t183-check.html
# Task list board loads
curl -sf http://localhost:3000/tasks?view=board -o /tmp/board-check.html && grep -q "kanban-board" /tmp/board-check.html
# Task list view loads
curl -sf "http://localhost:3000/tasks?view=list" -o /tmp/list-check.html && grep -q "inline-status-select" /tmp/list-check.html

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

### 2026-02-19T00:02:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-183-productionize-web-ui-inline-editing-t-18.md
- **Context:** Initial task creation

### 2026-02-19T00:21:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T00:25:17Z — status-update [task-update-agent]
- **Change:** owner: human → claude-code

### 2026-02-19T00:25:23Z — status-update [task-update-agent]
- **Change:** owner: claude-code → human
