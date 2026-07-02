---
id: T-970
name: "5 initial Playwright regression tests — terminal, inception, tasks, fabric,
  search (T-968 Phase 2)"
description: >
  Write 5 Playwright test files covering key Watchtower features: test_terminal.py
  (xterm loads, multi-session tabs, TermLink attach), test_inception.py (batch review,
  recommendations inline), test_tasks.py (task list, detail view), test_fabric.py
  (overview, component detail), test_smoke.py (all routes return 200 with content).

status: work-completed
workflow_type: test
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-06T19:38:01Z
last_update: '2026-06-11T22:24:33Z'
date_finished: 2026-04-12T07:55:37Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-970: 5 initial Playwright regression tests — terminal, inception, tasks, fabric, search (T-968 Phase 2)

## Context

T-968 Phase 2. With T-969 infrastructure in place (conftest.py, test_smoke.py, fw test playwright), write 5 additional Playwright test files covering key Watchtower features. These become permanent regression guards.

## Acceptance Criteria

### Agent
- [x] `tests/playwright/test_tasks.py` — task list (3 tests), task detail (2 tests)
- [x] `tests/playwright/test_inception.py` — inception list (3 tests), inception detail (3 tests)
- [x] `tests/playwright/test_fabric.py` — fabric overview (3 tests), component detail (2 tests), graph (1 test)
- [x] `tests/playwright/test_terminal.py` — terminal page (7 tests: container, tabs, buttons, status, xterm)
- [x] `tests/playwright/test_review.py` — approvals (2 tests), review page (2 tests)
- [x] All tests pass: `fw test playwright` — 40/40 passed in 77s
- [x] Verification commands pass

## Verification

test -f tests/playwright/test_tasks.py
test -f tests/playwright/test_inception.py
test -f tests/playwright/test_fabric.py
test -f tests/playwright/test_terminal.py
test -f tests/playwright/test_review.py
python3 -m pytest tests/playwright/ --co -q 2>/dev/null | tail -1

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

### 2026-04-06T19:38:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-970-5-initial-playwright-regression-tests--t.md
- **Context:** Initial task creation

### 2026-04-06T20:13:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T07:55:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-79f20053
- **Timestamp:** 2026-06-02T15:05:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
