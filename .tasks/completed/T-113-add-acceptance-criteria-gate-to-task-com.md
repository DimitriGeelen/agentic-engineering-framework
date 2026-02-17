---
id: T-113
name: Add acceptance criteria gate to task completion
description: >
  update-task.sh currently sets work-completed unconditionally. Add validation: (1) task template includes Acceptance Criteria section with checkboxes, (2) update-task.sh parses AC checkboxes and refuses work-completed unless all checked or --force bypass with reason logged. Ref: T-112 forensic analysis, L-034, FP-006, D-022, docs/reports/2026-02-17-premature-task-closure-analysis.md
status: work-completed
workflow_type: build
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T13:37:01Z
last_update: 2026-02-17T14:42:54Z
date_finished: 2026-02-17T14:42:54Z
---

# T-113: Add acceptance criteria gate to task completion

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T13:37:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-113-add-acceptance-criteria-gate-to-task-com.md
- **Context:** Initial task creation

### 2026-02-17T14:41:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-17T14:42:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
