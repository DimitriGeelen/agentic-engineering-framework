---
id: T-1027
name: "Fix graduation page Playwright test timeout"
description: >
  Fix graduation page Playwright test timeout

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T12:42:33Z
last_update: 2026-04-07T12:42:33Z
date_finished: null
---

# T-1027: Fix graduation page Playwright test timeout

## Context

test_graduation_has_directive_context times out on `wait_for_load_state("networkidle")` — graduation page likely has slow/pending requests. Fix by using `domcontentloaded` instead.

## Acceptance Criteria

### Agent
- [x] test_graduation.py uses domcontentloaded instead of networkidle
- [x] test_graduation_has_directive_context passes

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_graduation.py -x -q 2>&1 | tail -5

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

### 2026-04-07T12:42:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1027-fix-graduation-page-playwright-test-time.md
- **Context:** Initial task creation
