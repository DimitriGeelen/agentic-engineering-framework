---
id: T-1209
name: "Fix Watchtower 500 on consumer home — datetime.date vs datetime.datetime in stale tasks"
description: >
  Fix Watchtower 500 on consumer home — datetime.date vs datetime.datetime in stale tasks

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [web/blueprints/core.py]
related_tasks: []
created: 2026-04-13T08:48:45Z
last_update: 2026-04-13T08:51:21Z
date_finished: 2026-04-13T08:51:21Z
---

# T-1209: Fix Watchtower 500 on consumer home — datetime.date vs datetime.datetime in stale tasks

## Context

Consumer Watchtower home page returns 500. Root cause: `_get_stale_tasks()` in `web/blueprints/core.py`
does `now - last` where YAML parses `last_update`/`created` as `datetime.date` (not `datetime.datetime`).
Fix: coerce `datetime.date` to `datetime.datetime` before subtraction.

## Acceptance Criteria

### Agent
- [x] `_get_stale_tasks()` handles `datetime.date` objects from YAML
- [x] Framework Watchtower home page loads (HTTP 200)
- [x] Consumer Watchtower home page loads after restart

## Verification

# Framework home page loads
curl -sf -o /dev/null -w "%{http_code}" http://localhost:3000/ | grep -q 200

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

### 2026-04-13T08:48:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1209-fix-watchtower-500-on-consumer-home--dat.md
- **Context:** Initial task creation

### 2026-04-13T08:51:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
