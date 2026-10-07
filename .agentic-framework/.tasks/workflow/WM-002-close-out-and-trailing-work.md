---
id: WM-002
name: "Close-out and trailing work — what a task still owes after it closes"
description: >
  Standing workflow-management task. Focus here for the work a task owes AFTER
  --status work-completed has cleared focus. Never closes. Fenced: no source writes.
status: standing
workflow_type: workflow-management
owner: agent
fence: no-source-writes
created: 2026-09-28
---

# WM-002: Close-out and trailing work

## What this is for

`--status work-completed` clears focus as its last act, and `fw context focus
<closed-id>` then refuses — *"Focus must name a task the gates can still work
under."* Everything the task still owes becomes unreachable at that moment:

- `bin/fw vendor self` for vendored paths that were touched
- `fw context add-learning` — which the framework **prompts for at close and
  then refuses**
- `fw termlink cleanup` for workers the task spawned
- committing work that was staged but not yet committed

Measured cost before this existed: a worker filed **T-3530 purely to run
`git commit`** on its own finished deliverable, and a learning the framework had
just asked for could not be recorded.

## The fence

**No source writes.** If close-out needs to change source, it is not close-out —
it is a fix, and a fix needs its own task with its own acceptance criteria.

## Scope, and why it is capability-scoped not task-scoped

WM-002 is **not** bound to the id of the task that just closed. That was
considered and rejected for v1: binding it would need `update-task.sh` to hand
the id across the close boundary, which couples the fence to the very transition
that is already the fragile part (see OBS-468, where close *fails* to clear focus
under session-scoped focus and deadlocks the session).

Capability-scoping bounds it just as tightly for the property that matters: no
source writes, whatever task the work belongs to. Revisit if the log shows
WM-002 being used for something that is not trailing work.

## Log

<!-- ### YYYY-MM-DDTHH:MMZ — T-NNNN: <what was owed, what was done> -->
