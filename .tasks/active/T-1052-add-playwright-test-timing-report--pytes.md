---
id: T-1052
name: "Add Playwright test timing report — pytest conftest hook for slow test reporting"
description: >
  Add Playwright test timing report — pytest conftest hook for slow test reporting

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T17:47:46Z
last_update: 2026-04-07T17:47:46Z
date_finished: null
---

# T-1052: Add Playwright test timing report — pytest conftest hook for slow test reporting

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [ ] conftest.py pytest_terminal_summary hook prints slowest 10 tests
- [ ] Test collection succeeds
- [ ] `fw test playwright` shows timing report at end

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-07T17:47:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1052-add-playwright-test-timing-report--pytes.md
- **Context:** Initial task creation
