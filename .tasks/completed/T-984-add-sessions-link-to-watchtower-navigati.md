---
id: T-984
name: "Add Sessions link to Watchtower navigation"
description: >
  Add /sessions to the site navigation bar so users can access the sessions management page.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [web/shared.py]
related_tasks: []
created: 2026-04-06T23:24:00Z
last_update: 2026-04-06T23:25:49Z
date_finished: 2026-04-06T23:25:49Z
---

# T-984: Add Sessions link to Watchtower navigation

## Context

T-983 created /sessions page. Add it to the navigation bar under Architecture group next to Terminal.

## Acceptance Criteria

### Agent
- [x] `web/shared.py` NAV_GROUPS updated with Sessions link under Architecture
- [x] /sessions appears in navigation on any page

## Verification

grep -q 'sessions_page' web/shared.py
curl -sf http://localhost:3000/ -o /tmp/fw-verify-sessions.html && grep -q 'Sessions' /tmp/fw-verify-sessions.html

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

### 2026-04-06T23:24:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-984-add-sessions-link-to-watchtower-navigati.md
- **Context:** Initial task creation

### 2026-04-06T23:25:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
