---
id: T-004
name: "Complete a full task lifecycle for __PROJECT_NAME__"
description: >
  Create a new task for real work on __PROJECT_NAME__, complete it, and verify the full
  lifecycle works: create → start → work → complete → episodic generation.
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

Create a genuine task for __PROJECT_NAME__ (not busywork), complete it, and verify the framework captures it correctly. This validates: task creation, status transitions, acceptance criteria gating, episodic memory generation.

## Acceptance Criteria

### Agent
- [ ] Create a new task: `fw work-on "description" --type build`
- [ ] Complete the task with real work (small feature, fix, or improvement)
- [ ] Set status to work-completed: `fw task update T-XXX --status work-completed`
- [ ] Episodic summary generated in `.context/episodic/`

## Verification

# At least one completed task exists
test "$(ls .tasks/completed/T-*.md 2>/dev/null | wc -l)" -ge "1"
# At least one episodic summary exists
test "$(ls .context/episodic/T-*.yaml 2>/dev/null | wc -l)" -ge "1"
