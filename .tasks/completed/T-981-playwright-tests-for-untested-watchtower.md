---
id: T-981
name: "Playwright tests for untested Watchtower pages (timeline, config, costs, approvals)"
description: >
  Add Playwright regression tests for 4 uncovered pages: /timeline, /config, /costs,
  /approvals. Extends T-970 initial test coverage.

status: work-completed
workflow_type: test
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-06T22:46:09Z
last_update: '2026-08-16T22:25:44Z'
date_finished: 2026-04-06T22:50:25Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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
