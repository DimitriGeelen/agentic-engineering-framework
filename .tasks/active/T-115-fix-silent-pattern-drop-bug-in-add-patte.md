---
id: T-115
name: Fix silent pattern drop bug in add-pattern command
description: >
  context.sh add-pattern silently drops entries when appending to non-empty sections. Root cause: awk script uses prev~section which never matches (prev is last data line, not section header). Fix: track in_section state. Found during T-112 investigation when FP-006 was 'added' but missing from file. Ref: L-034, FP-006.
status: started-work
workflow_type: build
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T13:54:04Z
last_update: 2026-02-17T13:54:04Z
date_finished: null
---

# T-115: Fix silent pattern drop bug in add-pattern command

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T13:54:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-115-fix-silent-pattern-drop-bug-in-add-patte.md
- **Context:** Initial task creation
