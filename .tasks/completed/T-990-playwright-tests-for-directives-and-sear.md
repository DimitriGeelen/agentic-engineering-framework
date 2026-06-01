---
id: T-990
name: "Playwright tests for directives and search pages"
description: >
  Playwright tests for directives and search pages

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: [tests/playwright/test_directives.py, tests/playwright/test_search.py]
related_tasks: []
created: 2026-04-07T08:26:34Z
last_update: 2026-04-07T08:28:40Z
date_finished: 2026-04-07T08:28:40Z
---

# T-990: Playwright tests for directives and search pages

## Context

/directives and /search nav routes lack Playwright regression tests. Completes full nav coverage.

## Acceptance Criteria

### Agent
- [x] test_directives.py covers directives page load, heading, and constitutional directive content
- [x] test_search.py covers search page load and search functionality
- [x] All new tests pass (8/8)
- [x] Fabric cards registered

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_directives.py tests/playwright/test_search.py -x -q 2>&1 | tail -5

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

### 2026-04-07T08:26:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-990-playwright-tests-for-directives-and-sear.md
- **Context:** Initial task creation

### 2026-04-07T08:28:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
