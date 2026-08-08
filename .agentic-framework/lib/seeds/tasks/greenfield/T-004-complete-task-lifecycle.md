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

## For the Operator

**What is happening:** the agent runs one task all the way round the loop — create, work,
complete — so the machinery has been exercised once before it matters.

**Why it matters to you:** completion is not the agent declaring itself finished. Two gates
run mechanically first. **P-010** refuses to close a task with unticked agent acceptance
criteria. **P-011** executes the shell commands the agent wrote in the task's
`## Verification` block and refuses if any of them fails. The agent cannot talk its way
past either — they run commands and read exit codes.

Then an **episodic summary** is generated into `.context/episodic/`. That is the project's
memory: what was done, what was decided, what broke. Later sessions read it, which is how
the framework avoids relearning the same lesson.

**What you can do meanwhile:** watch it happen in Watchtower. The task moves through its
states in front of you, which is a faster way to understand the model than reading about it.

**Go deeper:** `fw corpus explain aef-task-lifecycle` — including the refusal loop when a
gate says no.

## Acceptance Criteria

### Agent
- [ ] Create a new task: `fw work-on "description" --type build`
- [ ] Complete the task with real work
- [ ] Set status to work-completed: `fw task update T-XXX --status work-completed`
- [ ] Episodic summary generated in `.context/episodic/`

## Verification

# At least one completed task exists (beyond onboarding tasks)
test "$(ls .tasks/completed/T-*.md 2>/dev/null | wc -l)" -ge "1"

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
