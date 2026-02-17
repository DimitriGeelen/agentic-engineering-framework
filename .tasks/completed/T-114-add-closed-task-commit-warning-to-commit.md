---
id: T-114
name: Add closed task commit warning to commit-msg hook
description: >
  commit-msg hook currently only validates task reference format (T-XXX pattern). Add check: if referenced task ID exists in .tasks/completed/, print warning 'Task T-XXX is closed. Consider creating a new task or reopening.' Tier 1 warning (does not block). Ref: T-112 forensic analysis, L-034, FP-006, D-022, docs/reports/2026-02-17-premature-task-closure-analysis.md
status: work-completed
workflow_type: build
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T13:37:06Z
last_update: 2026-02-17T14:39:22Z
date_finished: 2026-02-17T14:39:22Z
---

# T-114: Add closed task commit warning to commit-msg hook

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T13:37:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-114-add-closed-task-commit-warning-to-commit.md
- **Context:** Initial task creation

### 2026-02-17T14:38:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-17T14:39:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
