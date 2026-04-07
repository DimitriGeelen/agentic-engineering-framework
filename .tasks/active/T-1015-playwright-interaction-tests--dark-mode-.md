---
id: T-1015
name: "Playwright interaction tests — dark mode toggle, task filtering, search"
description: >
  Playwright interaction tests — dark mode toggle, task filtering, search

status: started-work
workflow_type: test
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T10:30:31Z
last_update: 2026-04-07T10:30:31Z
date_finished: null
---

# T-1015: Playwright interaction tests — dark mode toggle, task filtering, search

## Context

Existing Playwright tests are page-load only. Add interaction tests: dark mode toggle, search input, task page filtering.

## Acceptance Criteria

### Agent
- [x] test_interactions.py with dark mode toggle (3), search input (2), and task filter (2) tests
- [x] All tests pass (7/7)
- [x] Fabric card registered

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_interactions.py -x -q 2>&1 | tail -5

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

### 2026-04-07T10:30:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1015-playwright-interaction-tests--dark-mode-.md
- **Context:** Initial task creation
