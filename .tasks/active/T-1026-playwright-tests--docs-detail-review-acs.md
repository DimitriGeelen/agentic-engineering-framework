---
id: T-1026
name: "Playwright tests — docs detail, review ACs, POST error handling"
description: >
  Playwright tests — docs detail, review ACs, POST error handling

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T12:29:39Z
last_update: 2026-04-07T12:29:39Z
date_finished: null
---

# T-1026: Playwright tests — docs detail, review ACs, POST error handling

## Context

Continues T-1025 Playwright expansion. Covers docs detail pages, review ACs htmx fragment, and POST endpoint error handling. Total coverage target: 230+ tests.

## Acceptance Criteria

### Agent
- [ ] test_docs_detail.py — /docs/generated/<card_name> detail page loads, nonexistent 404
- [ ] test_review_acs.py — /review/<task_id>/acs returns AC fragment, invalid 404
- [ ] test_api_task_mutations.py — POST endpoints return 400 for invalid input (create, horizon, status)
- [ ] test_api_healing.py — /api/healing/<task_id> POST with invalid task returns error
- [ ] All new tests pass

## Verification

ls tests/playwright/test_docs_detail.py tests/playwright/test_review_acs.py tests/playwright/test_api_task_mutations.py tests/playwright/test_api_healing.py
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_docs_detail.py tests/playwright/test_review_acs.py tests/playwright/test_api_task_mutations.py tests/playwright/test_api_healing.py -x -q 2>&1 | tail -5

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

### 2026-04-07T12:29:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1026-playwright-tests--docs-detail-review-acs.md
- **Context:** Initial task creation
