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

## For the Operator

**What is happening:** the agent runs one real task all the way round the loop — create,
work, complete — on __PROJECT_NAME__, so the machinery has been exercised once before it
matters.

**Why it matters to you:** completion is not the agent declaring itself finished. Two gates
run mechanically first. **P-010** refuses to close a task with unticked agent acceptance
criteria. **P-011** executes the shell commands the agent wrote in the task's
`## Verification` block and refuses if any of them fails. Neither can be argued with — they
run commands and read exit codes.

Then an **episodic summary** lands in `.context/episodic/`. That is the project's memory:
what was done, what was decided, what broke. Later sessions read it, which is how the
framework stops relearning the same lesson every few weeks.

**What you can do meanwhile:** watch it in Watchtower. Seeing a task move through its states
teaches the model faster than reading about it. This is also your first look at the agent
doing real work under governance rather than onboarding chores — worth judging.

**Go deeper:** `fw corpus explain aef-task-lifecycle` — including the refusal loop when a
gate says no.

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
