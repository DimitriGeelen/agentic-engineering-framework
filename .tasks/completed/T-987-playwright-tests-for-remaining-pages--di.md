---
id: T-987
name: "Playwright tests for remaining pages — discoveries, docs, settings"
description: >
  Playwright tests for remaining pages — discoveries, docs, settings

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: [tests/playwright/test_discoveries.py, tests/playwright/test_docs.py, tests/playwright/test_settings.py]
related_tasks: []
created: 2026-04-07T08:03:25Z
last_update: 2026-04-07T08:05:14Z
date_finished: 2026-04-07T08:05:14Z
---

# T-987: Playwright tests for remaining pages — discoveries, docs, settings

## Context

3 remaining Watchtower pages without Playwright regression tests: discoveries, docs/generated, settings.

## Acceptance Criteria

### Agent
- [x] test_discoveries.py covers discoveries dashboard load and content
- [x] test_docs.py covers generated docs page load and content
- [x] test_settings.py covers settings page load and content
- [x] All new tests pass (12/12)
- [x] Fabric cards registered for new test files

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_discoveries.py tests/playwright/test_docs.py tests/playwright/test_settings.py -x -q 2>&1 | tail -5

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

### 2026-04-07T08:03:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-987-playwright-tests-for-remaining-pages--di.md
- **Context:** Initial task creation

### 2026-04-07T08:05:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d4d1742d
- **Timestamp:** 2026-06-02T15:06:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
