---
id: T-1003
name: "Playwright navigation test — verify htmx nav links load content fragments"
description: >
  Playwright navigation test — verify htmx nav links load content fragments

status: started-work
workflow_type: test
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T10:07:34Z
last_update: 2026-04-07T10:10:45Z
date_finished: null
---

# T-1003: Playwright navigation test — verify htmx nav links load content fragments

## Context

Tests that Watchtower nav links work — clicking between pages loads correct content via htmx.

## Acceptance Criteria

### Agent
- [x] test_navigation.py verifies sequential page navigation works
- [x] Tests cover 4 nav transitions + link presence + all routes return 200
- [x] All tests pass (6/6)

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_navigation.py -x -q 2>&1 | tail -5

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

### 2026-04-07T10:07:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1003-playwright-navigation-test--verify-htmx-.md
- **Context:** Initial task creation
