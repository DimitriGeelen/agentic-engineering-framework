---
id: T-979
name: "Playwright tests for web terminal session API (T-967 follow-up)"
description: >
  Add Playwright tests for /api/sessions CRUD endpoints and /api/sessions/profiles.
  Verifies T-967 provider registry and session management API.

status: work-completed
workflow_type: test
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-06T22:32:24Z
last_update: '2026-06-11T22:24:33Z'
date_finished: 2026-04-06T22:34:03Z
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

# T-979: Playwright tests for web terminal session API (T-967 follow-up)

## Context

T-967 added session API endpoints (`/api/sessions`, `/api/sessions/profiles`). Per T-971 AC-to-test workflow rule, these need Playwright regression tests.

## Acceptance Criteria

### Agent
- [x] `tests/playwright/test_session_api.py` — tests for /api/sessions (GET empty, POST create, GET by id, DELETE), /api/sessions/profiles (12 tests)
- [x] All new tests pass (12/12 in 1.94s)
- [x] Existing 40 Playwright tests still pass (52 total collected)

## Verification

test -f tests/playwright/test_session_api.py
python3 -m pytest tests/playwright/test_session_api.py -v
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

### 2026-04-06T22:32:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-979-playwright-tests-for-web-terminal-sessio.md
- **Context:** Initial task creation

### 2026-04-06T22:34:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-70ee7a40
- **Timestamp:** 2026-06-02T15:06:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
