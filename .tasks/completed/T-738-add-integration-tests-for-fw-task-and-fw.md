---
id: T-738
name: "Add integration tests for fw task and fw context commands"
description: >
  Add integration tests for fw task and fw context commands

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: [tests/integration/fw_context.bats, tests/integration/fw_task.bats]
related_tasks: []
created: 2026-03-29T21:11:01Z
last_update: 2026-03-29T21:16:19Z
date_finished: 2026-03-29T21:16:19Z
---

# T-738: Add integration tests for fw task and fw context commands

## Context

Core CLI commands `fw task` and `fw context` have no integration tests. These test the task create/update and context status/focus flows.

## Acceptance Criteria

### Agent
- [x] tests/integration/fw_task.bats created — 5 tests (create, placeholder rejection, update fail, help, list)
- [x] tests/integration/fw_context.bats created — 4 tests (init, focus empty, focus set, help)
- [x] All 9 tests pass (robust — no hardcoded IDs, works in verification gate)

## Verification

test -f tests/integration/fw_task.bats
test -f tests/integration/fw_context.bats

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-03-29T21:11:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-738-add-integration-tests-for-fw-task-and-fw.md
- **Context:** Initial task creation

### 2026-03-29T21:16:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
