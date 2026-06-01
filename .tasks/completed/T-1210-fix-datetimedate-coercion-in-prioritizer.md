---
id: T-1210
name: "Fix datetime.date coercion in prioritizer.py and rules.py (T-1209 follow-up)"
description: >
  Fix datetime.date coercion in prioritizer.py and rules.py (T-1209 follow-up)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-13T09:00:19Z
last_update: 2026-04-13T09:02:29Z
date_finished: 2026-04-13T09:02:29Z
---

# T-1210: Fix datetime.date coercion in prioritizer.py and rules.py (T-1209 follow-up)

## Context

Same datetime.date bug class as T-1209. `_parse_datetime()` in prioritizer.py and date handling
in rules.py don't handle YAML date objects. Follow-up to ensure the bug class is eliminated.

## Acceptance Criteria

### Agent
- [x] prioritizer.py `_parse_datetime()` handles `datetime.date` objects
- [x] rules.py date handling handles `datetime.date` objects (already fixed)
- [x] Watchtower health endpoint returns ok after restart

## Verification

# Watchtower health check
curl -sf http://localhost:3001/health | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['app']=='ok', f'unhealthy: {d}'"

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

### 2026-04-13T09:00:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1210-fix-datetimedate-coercion-in-prioritizer.md
- **Context:** Initial task creation

### 2026-04-13T09:02:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
