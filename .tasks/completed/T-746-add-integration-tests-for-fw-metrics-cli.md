---
id: T-746
name: "Add integration tests for fw metrics CLI"
description: >
  No integration test coverage for fw metrics.

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-03-29T23:46:41Z
last_update: 2026-03-29T23:48:40Z
date_finished: 2026-03-29T23:48:40Z
---

# T-746: Add integration tests for fw metrics CLI

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `tests/integration/fw_metrics.bats` created with 4 tests: dashboard, counts, dashboard subcommand, predict
- [x] All tests pass
- [x] Component card registered

## Verification

test -f tests/integration/fw_metrics.bats
bats tests/integration/fw_metrics.bats

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

### 2026-03-29T23:46:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-746-add-integration-tests-for-fw-metrics-cli.md
- **Context:** Initial task creation

### 2026-03-29T23:48:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
