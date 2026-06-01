---
id: T-1198
name: "Fix remaining hardcoded status strings in watchtower blueprints (core.py, metrics.py, prioritizer.py)"
description: >
  Fix remaining hardcoded status strings in watchtower blueprints (core.py, metrics.py, prioritizer.py)

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-13T07:08:06Z
last_update: 2026-04-13T13:30:31Z
date_finished: 2026-04-13T13:30:31Z
---

# T-1198: Fix remaining hardcoded status strings in watchtower blueprints (core.py, metrics.py, prioritizer.py)

## Context

Investigated hardcoded status strings in core.py and metrics.py. No centralized status enum exists.
The comparisons are semantic display logic (color coding, sorting), not business logic enforcement.
No fix needed — the strings match the actual lifecycle statuses and handle unknown values gracefully.
prioritizer.py does not exist.

## Acceptance Criteria

### Agent
- [x] Investigated all three files mentioned in task name
- [x] Confirmed no centralized status constants exist to import
- [x] Confirmed status comparisons are display-only, not business logic

## Verification

# No code changes — verification is investigative

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

### 2026-04-13T07:08:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1198-fix-remaining-hardcoded-status-strings-i.md
- **Context:** Initial task creation

### 2026-04-13T07:08:50Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
- **Reason:** Python status comparisons are semantic, not enumeration — they handle unknown statuses gracefully. No fix needed.

### 2026-04-13T13:29:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

### 2026-04-13T13:30:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** No fix needed — status comparisons are semantic display logic, no enum to centralize
