---
id: T-076
name: Fix fw work-on to prompt for description
description: >
  fw work-on creates tasks with boilerplate description 'Created via fw work-on'. This caused 5 SKELETON tasks (T-060,T-068-T-071). Fix: add --description flag passthrough or interactive prompt when description not provided. Located in bin/fw work-on command handler which calls create-task.sh. See docs/reports/2026-02-15-context-memory-audit.md Section 1 root causes.
status: captured
workflow_type: build
owner: agent
created: 2026-02-15T16:57:58Z
last_update: 2026-02-15T16:57:58Z
date_finished: null
---

# T-076: Fix fw work-on to prompt for description

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-15T16:57:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-076-fix-fw-work-on-to-prompt-for-description.md
- **Context:** Initial task creation
