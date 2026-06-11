---
id: T-1344
name: "Retrofit playwright conftest with CSRF token fixture (T-1343 regression hotfix)"
description: >
  Retrofit playwright conftest with CSRF token fixture (T-1343 regression hotfix)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/playwright/conftest.py]
related_tasks: []
created: 2026-04-20T07:26:44Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-20T07:54:09Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1344: Retrofit playwright conftest with CSRF token fixture (T-1343 regression hotfix)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `tests/playwright/conftest.py` `page` fixture primes session with CSRF token via meta tag
- [x] Token is injected as `X-CSRF-Token` default header on browser context so `page.request.post(...)` works
- [x] `pytest tests/playwright/test_api_task_complete.py` passes against live Watchtower
- [x] Regression spot-check: 2+ other `/api/*` POST test files pass

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-20T07:26:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1344-retrofit-playwright-conftest-with-csrf-t.md
- **Context:** Initial task creation

### 2026-04-20T07:54:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bce74d8a
- **Timestamp:** 2026-06-02T14:56:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `tests/playwright/conftest.py` `page` fixture primes session with CSRF token via meta tag
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/conftest.py in: `tests/playwright/conftest.py` `page` fixture primes session with CSRF token via meta tag`
- **AC#3 (Agent)** — `pytest tests/playwright/test_api_task_complete.py` passes against live Watchtower
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/test_api_task_complete.py in: `pytest tests/playwright/test_api_task_complete.py` passes against live Watchtower`
