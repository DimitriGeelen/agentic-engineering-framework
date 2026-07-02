---
id: T-969
name: "Playwright test infrastructure — tests/playwright/ + fw test playwright + conftest.py
  (T-968 Phase 1)"
description: >
  Add pytest-playwright to the framework. Create tests/playwright/ with conftest.py
  (server fixture, browser fixture), test_smoke.py (all routes 200), and fw test playwright
  sub-command. CI integration in GitHub Actions.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-06T19:37:58Z
last_update: '2026-06-11T22:24:33Z'
date_finished: 2026-04-12T07:55:35Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-969: Playwright test infrastructure — tests/playwright/ + fw test playwright + conftest.py (T-968 Phase 1)

## Context

T-968 inception (GO) identified the gap: `fw test` has 5 sub-commands with 1086 tests but zero Playwright tests. This task adds `tests/playwright/` directory with conftest.py (server fixture, browser fixture), a smoke test, and `fw test playwright` sub-command. Design: `docs/reports/T-968-v2-playwright-infra.md`.

## Acceptance Criteria

### Agent
- [x] `tests/playwright/conftest.py` exists with server fixture (start Watchtower on port 3099) and browser fixture
- [x] `tests/playwright/test_smoke.py` exists with at least 3 route smoke tests (12 tests: 3 homepage, 6 core pages, 3 navigation)
- [x] `fw test playwright` sub-command added to `bin/fw`
- [x] `fw test all` includes playwright tests
- [x] `fw test playwright` runs successfully — 12/12 passed
- [x] Help text updated to show playwright option
- [x] Verification commands pass

## Verification

test -f tests/playwright/conftest.py
test -f tests/playwright/test_smoke.py
python3 -c "import playwright; print('playwright installed')"
grep -q 'playwright' bin/fw

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

### 2026-04-06T19:37:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-969-playwright-test-infrastructure--testspla.md
- **Context:** Initial task creation

### 2026-04-06T20:05:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T07:55:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1a4c9428
- **Timestamp:** 2026-06-02T15:05:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
