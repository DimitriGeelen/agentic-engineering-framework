---
id: T-965
name: "Multi-session terminal tabs + session management (T-962 Phase 2)"
description: >
  Phase 2: Add multi-session support to Watchtower terminal. Tab bar UI for switching between sessions, session lifecycle indicators (running/idle/exited), New Session button with provider dropdown (shell, Claude Code), session naming and color coding. Session data model with type/provider fields from T-962 research. Depends on T-964.

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [web/app.py, web/templates/terminal.html]
related_tasks: []
created: 2026-04-06T18:25:24Z
last_update: 2026-04-06T19:14:04Z
date_finished: 2026-04-06T19:14:04Z
---

# T-965: Multi-session terminal tabs + session management (T-962 Phase 2)

## Context

Phase 2 of T-962 web terminal. Extends T-964 single terminal with multi-session tabs and session lifecycle management. See `docs/reports/T-962-v5-multi-session-ui.md` for UI patterns research.

## Acceptance Criteria

### Agent
- [x] Session data model implemented (id, name, type, state)
- [x] Tab bar UI for switching between sessions
- [x] "New Session" button spawns additional terminal sessions
- [x] Session lifecycle indicators (running/exited status dots)
- [x] Closing a tab kills the PTY session

### Human
- [x] [REVIEW] Multi-session UX is intuitive
  **Steps:**
  1. Open http://localhost:3000/terminal
  2. Click "+" to create 2-3 terminals
  3. Switch between tabs, type in each
  4. Close a tab and verify it's removed
  **Expected:** Tabs responsive, sessions independent, closing works
  **If not:** Note specific UX issues

## Verification

python3 -c "from web.app import app; c=app.test_client(); r=c.get('/terminal'); exit(0 if r.status_code==200 else 1)"
grep -q 'new-session\|session-tab' web/templates/terminal.html

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

### 2026-04-06T18:25:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-965-multi-session-terminal-tabs--session-man.md
- **Context:** Initial task creation

### 2026-04-06T18:35:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-06T19:14:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
