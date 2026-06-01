---
id: T-988
name: "Fix Playwright settings test timeout — add 60s timeout for batch run contention"
description: >
  Fix Playwright settings test timeout — add 60s timeout for batch run contention

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/playwright/test_settings.py]
related_tasks: []
created: 2026-04-07T08:08:03Z
last_update: 2026-04-07T08:17:39Z
date_finished: 2026-04-07T08:17:39Z
---

# T-988: Fix Playwright settings test timeout — add 60s timeout for batch run contention

## Context

Settings page may make Ollama connection checks that timeout under batch test contention. Same pattern as T-982 timeline fix.

## Acceptance Criteria

### Agent
- [x] test_settings.py uses 60s goto timeout and domcontentloaded (networkidle hangs on Ollama connection check)
- [x] Settings tests pass in isolation and in batch with other new tests (49/49)

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_settings.py -x -q 2>&1 | tail -5

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

### 2026-04-07T08:08:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-988-fix-playwright-settings-test-timeout--ad.md
- **Context:** Initial task creation

### 2026-04-07T08:17:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
