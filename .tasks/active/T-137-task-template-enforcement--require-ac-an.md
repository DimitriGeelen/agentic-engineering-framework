---
id: T-137
name: Task template enforcement — require AC and Verification on creation
description: >
  create-task.sh generates tasks with placeholder AC and Verification sections that the agent never fills in. Sprechloop cycle 2: 11 tasks created as stubs, all completed without AC or Verification. Change: (1) create-task.sh should include a real AC section with at least one placeholder checkbox that must be edited, (2) include a Verification section with a comment explaining what to add, (3) update-task.sh should WARN (not block) when transitioning to started-work if AC section still has only placeholder text. Blocking is too aggressive — but warning makes the obligation visible.
status: captured
workflow_type: build
horizon: now
owner: human
tags: []
related_tasks: []
created: 2026-02-17T23:49:42Z
last_update: 2026-02-17T23:49:42Z
date_finished: null
---

# T-137: Task template enforcement — require AC and Verification on creation

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T23:49:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-137-task-template-enforcement--require-ac-an.md
- **Context:** Initial task creation
