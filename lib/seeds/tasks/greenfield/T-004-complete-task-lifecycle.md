---
id: T-004
name: "Complete a full task lifecycle for __PROJECT_NAME__"
description: >
  Create a task for real work, complete it, and verify the lifecycle: create → start →
  work → complete → episodic generation.
status: captured
workflow_type: build
owner: agent
horizon: now
tags: [onboarding]
components: []
related_tasks: []
created: __DATE__
last_update: __DATE__
date_finished: null
---

# T-004: Complete a full task lifecycle for __PROJECT_NAME__

## Context

Create a genuine task (small feature or improvement), complete it, and verify the framework captures it. Validates: task creation, status transitions, AC gating, episodic memory.

## Acceptance Criteria

### Agent
- [ ] Create a new task: `fw work-on "description" --type build`
- [ ] Complete the task with real work
- [ ] Set status to work-completed: `fw task update T-XXX --status work-completed`
- [ ] Episodic summary generated in `.context/episodic/`

## Verification

# At least one completed task exists (beyond onboarding tasks)
test "$(ls .tasks/completed/T-*.md 2>/dev/null | wc -l)" -ge "1"
