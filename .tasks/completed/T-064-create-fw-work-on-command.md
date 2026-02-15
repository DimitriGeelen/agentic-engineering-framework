---
id: T-064
name: Create fw work-on command
description: >
  T-061 finding: Task creation and focus-setting are separate manual steps, easy to skip. Create a single 'fw work-on' command that: (1) creates task if needed, (2) sets focus, (3) sets status to started-work, (4) outputs confirmation. This makes compliance easier than non-compliance (P-002 principle). Reduces 3 manual steps to 1.
status: work-completed
workflow_type: build
owner: agent
created: 2026-02-15T08:35:12Z
last_update: 2026-02-15T08:44:19Z
date_finished: 2026-02-15T08:44:19Z
---

# T-064: Create fw work-on command

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-15T08:35:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-064-create-fw-work-on-command.md
- **Context:** Initial task creation

### 2026-02-15T08:42:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** owner: human → agent

### 2026-02-15T08:44:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
