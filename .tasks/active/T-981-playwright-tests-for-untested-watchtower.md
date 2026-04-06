---
id: T-981
name: "Playwright tests for untested Watchtower pages (timeline, config, costs, approvals)"
description: >
  Add Playwright regression tests for 4 uncovered pages: /timeline, /config, /costs, /approvals. Extends T-970 initial test coverage.

status: started-work
workflow_type: test
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-06T22:46:09Z
last_update: 2026-04-06T22:47:51Z
date_finished: null
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
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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
