---
id: T-1029
name: "Playwright tests — scan API, task inline edit, session init"
description: >
  Playwright tests — scan API, task inline edit, session init

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T13:31:49Z
last_update: 2026-04-07T13:31:49Z
date_finished: null
---

# T-1029: Playwright tests — scan API, task inline edit, session init

## Context

Third batch of Playwright test expansion. Covers scan API validation, task inline edit error handling, and session init. Extends coverage from 230 to 240+ tests.

## Acceptance Criteria

### Agent
- [x] test_api_scan.py — scan/focus validates task ID, scan/refresh works (3 tests)
- [x] test_api_task_inline.py — name/description/toggle-ac/owner/type error handling (11 tests)
- [x] test_api_session_init.py — session init POST returns HTML (1 test)
- [x] All 15 new tests pass

## Verification

ls tests/playwright/test_api_scan.py tests/playwright/test_api_task_inline.py tests/playwright/test_api_session_init.py
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_api_scan.py tests/playwright/test_api_task_inline.py tests/playwright/test_api_session_init.py -x -q 2>&1 | tail -5

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

### 2026-04-07T13:31:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1029-playwright-tests--scan-api-task-inline-e.md
- **Context:** Initial task creation
