---
id: T-981
name: "Playwright tests for untested Watchtower pages (timeline, config, costs, approvals)"
description: >
  Add Playwright regression tests for 4 uncovered pages: /timeline, /config, /costs, /approvals. Extends T-970 initial test coverage.

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-06T22:46:09Z
last_update: 2026-04-06T22:50:25Z
date_finished: 2026-04-06T22:50:25Z
---

# T-981: Playwright tests for untested Watchtower pages (timeline, config, costs, approvals)

## Context

Extends T-970 initial test coverage. Four major Watchtower pages have no dedicated Playwright tests: /timeline, /config, /costs, /approvals.

## Acceptance Criteria

### Agent
- [x] `tests/playwright/test_timeline.py` — timeline page tests (4 tests)
- [x] `tests/playwright/test_config.py` — config page tests (4 tests)
- [x] `tests/playwright/test_costs.py` — costs page tests (4 tests)
- [x] `tests/playwright/test_approvals.py` — approvals page tests (4 tests)
- [x] All new tests pass (16/16 in 52s)
- [x] Total Playwright test count: 69 (up from 53)

## Verification

test -f tests/playwright/test_timeline.py
test -f tests/playwright/test_config.py
test -f tests/playwright/test_costs.py
test -f tests/playwright/test_approvals.py
python3 -m pytest tests/playwright/test_timeline.py tests/playwright/test_config.py tests/playwright/test_costs.py tests/playwright/test_approvals.py -v

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

### 2026-04-06T22:46:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-981-playwright-tests-for-untested-watchtower.md
- **Context:** Initial task creation

### 2026-04-06T22:50:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-aac21d0b
- **Timestamp:** 2026-06-02T15:06:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
