---
id: T-512
name: "Scope escalation counter — track new files per session in check-active-task.sh"
description: >
  Add new-file-per-session counter to check-active-task.sh. When a session creates >3 new source files under a single task, warn about scope escalation (pickup message governance, G-020). From T-477 Spike 3, Option A build task 4.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [governance, enforcement, D2]
components: [agents/context/check-fabric-new-file.sh]
related_tasks: []
created: 2026-03-17T11:34:13Z
last_update: 2026-03-17T11:45:11Z
date_finished: 2026-03-17T11:45:11Z
---

# T-512: Scope escalation counter — track new files per session in check-active-task.sh

## Context

From T-477. When a session creates >3 new source files under a single task, warn about scope escalation. Addresses G-020 (pickup message governance bypass — session-010-termlink created many files without inception). Advisory only — informational warning, not blocking.

## Acceptance Criteria

### Agent
- [x] `check-fabric-new-file.sh` tracks new file count per task in `.context/working/.new-file-counter`
- [x] Warning emitted when new file count exceeds 3 for current task
- [x] Counter resets when focus changes to a different task
- [x] Exempt paths (.context/, .tasks/, docs/) don't increment counter

## Verification

test -f agents/context/check-fabric-new-file.sh

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

### 2026-03-17T11:34:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-512-scope-escalation-counter--track-new-file.md
- **Context:** Initial task creation

### 2026-03-17T11:42:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-17T11:45:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
