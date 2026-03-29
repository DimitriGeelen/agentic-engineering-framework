---
id: T-738
name: "Add integration tests for fw task and fw context commands"
description: >
  Add integration tests for fw task and fw context commands

status: started-work
workflow_type: test
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-29T21:11:01Z
last_update: 2026-03-29T21:11:01Z
date_finished: null
---

# T-738: Add integration tests for fw task and fw context commands

## Context

Core CLI commands `fw task` and `fw context` have no integration tests. These test the task create/update and context status/focus flows.

## Acceptance Criteria

### Agent
- [x] tests/integration/fw_task.bats created — 7 tests (create, placeholder rejection, ID increment, update, update fail, help, list)
- [x] tests/integration/fw_context.bats created — 6 tests (status x2, init, focus empty, focus set, help)
- [x] All 13 tests pass

## Verification

bats tests/integration/fw_task.bats
bats tests/integration/fw_context.bats

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
