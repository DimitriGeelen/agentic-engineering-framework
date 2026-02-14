---
id: T-053
name: Fix fw task list default display
description: >
  Fix fw task list to show useful output when 0 active tasks. Show completed count + hint. Derive status from directory as fallback.
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: []
agents:
  primary:
  supporting: []
created: 2026-02-14T12:48:54Z
last_update: 2026-02-14T13:05:34Z
date_finished: 2026-02-14T13:05:34Z
---

# T-053: Fix fw task list default display

## Design Record

[Architecture decisions, approach rationale — inline or link to artifact]

## Specification Record

[Requirements, acceptance criteria — inline or link to artifact]

## Test Files

[References to test scripts and test artifacts]

## Updates

### 2026-02-14T12:48:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-053-fix-fw-task-list-default-display.md
- **Context:** Initial task creation

### 2026-02-14T13:05:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Task list shows completed count when no active tasks
