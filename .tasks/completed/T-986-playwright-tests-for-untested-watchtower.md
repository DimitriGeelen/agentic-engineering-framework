---
id: T-986
name: "Playwright tests for untested Watchtower pages — discovery, metrics, quality, enforcement, risks, cron, core"
description: >
  Playwright tests for untested Watchtower pages — discovery, metrics, quality, enforcement, risks, cron, core

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: [tests/playwright/test_core.py, tests/playwright/test_cron.py, tests/playwright/test_discovery.py, tests/playwright/test_enforcement.py, tests/playwright/test_metrics.py, tests/playwright/test_quality.py, tests/playwright/test_risks.py]
related_tasks: []
created: 2026-04-07T07:58:32Z
last_update: 2026-04-07T08:02:11Z
date_finished: 2026-04-07T08:02:11Z
---

# T-986: Playwright tests for untested Watchtower pages — discovery, metrics, quality, enforcement, risks, cron, core

## Context

12 Watchtower blueprints lack Playwright regression tests. Adds tests for: core (landing), discovery (learnings, decisions, gaps, patterns, graduation), metrics, quality, enforcement, risks, cron.

## Acceptance Criteria

### Agent
- [x] test_core.py covers landing page load, heading, content sections
- [x] test_discovery.py covers learnings, decisions, gaps pages
- [x] test_metrics.py covers metrics page load and content
- [x] test_quality.py covers quality gate page load and content
- [x] test_enforcement.py covers enforcement dashboard load and content
- [x] test_risks.py covers risk register page load and content
- [x] test_cron.py covers cron registry page load and content
- [x] All new tests pass with `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/ -x -q`
- [x] Fabric cards registered for all new test files

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_core.py tests/playwright/test_discovery.py tests/playwright/test_metrics.py tests/playwright/test_quality.py tests/playwright/test_enforcement.py tests/playwright/test_risks.py tests/playwright/test_cron.py -x -q 2>&1 | tail -5

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

### 2026-04-07T07:58:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-986-playwright-tests-for-untested-watchtower.md
- **Context:** Initial task creation

### 2026-04-07T08:02:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
