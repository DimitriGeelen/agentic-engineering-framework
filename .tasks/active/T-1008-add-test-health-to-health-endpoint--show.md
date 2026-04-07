---
id: T-1008
name: "Add test health to /health endpoint — show Playwright/unit/web test counts"
description: >
  Add test health to /health endpoint — show Playwright/unit/web test counts

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T10:14:32Z
last_update: 2026-04-07T10:14:32Z
date_finished: null
---

# T-1008: Add test health to /health endpoint — show Playwright/unit/web test counts

## Context

Enhance /health endpoint with test infrastructure counts — how many test files and test functions exist per suite (Playwright, unit, web). Helps monitor test health.

## Acceptance Criteria

### Agent
- [x] /health endpoint includes `tests` section with file counts per suite (playwright:27, unit:58, integration:69, web:1)
- [x] Playwright test for /health endpoint verifying test data presence (4 tests)
- [x] All tests pass

## Verification

cd /opt/999-Agentic-Engineering-Framework && curl -sf http://localhost:3000/health | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'tests' in d, 'missing tests key'; print('OK:', d['tests'])"

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

### 2026-04-07T10:14:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1008-add-test-health-to-health-endpoint--show.md
- **Context:** Initial task creation
