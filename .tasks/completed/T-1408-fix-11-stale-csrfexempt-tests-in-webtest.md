---
id: T-1408
name: "Fix 11 stale csrf_exempt tests in web/test_app.py — T-1343 removed /api/* exemption,
  tests not updated"
description: >
  Fix 11 stale csrf_exempt tests in web/test_app.py — T-1343 removed /api/* exemption,
  tests not updated

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-23T19:23:19Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-23T19:26:10Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1408: Fix 11 stale csrf_exempt tests in web/test_app.py — T-1343 removed /api/* exemption, tests not updated

## Context

T-1343 / G-048 removed the blanket `/api/*` CSRF exemption (web/app.py:102-105
comment + new logic enforcing CSRF on all POST/PATCH/PUT/DELETE except `/health`
and JSON `/search/*`). 11 tests in `web/test_app.py` still assert
`assert resp.status_code != 403` for unauthenticated POSTs to `/api/*`,
producing a deterministic 11-failure suite.

The tests are stale — they encode the *removed* policy. Fix: rewrite each
to assert that an unauthenticated POST returns 403 (CSRF rejected) AND that
a CSRF-authenticated POST does not return 403.

## Acceptance Criteria

### Agent
- [x] All 11 stale `*_csrf_exempt` tests rewritten to assert post-T-1343 CSRF policy
- [x] Each rewritten test asserts: unauth POST → 403 (CSRF rejected)
- [x] Renamed from `*_csrf_exempt` to `*_csrf_required` to reflect actual policy
- [x] No change to web/app.py csrf_protect (test fix only)
- [x] `python3 -m pytest web/test_app.py` — was 11 failures, now `142 passed in 56.63s`

## Verification

bash -c 'out=$(python3 -m pytest web/test_app.py 2>&1); echo "$out" | tail -3; echo "$out" | grep -qE "[0-9]+ passed" && ! echo "$out" | grep -qE "csrf_exempt.*FAIL"'

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

### 2026-04-23T19:23:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1408-fix-11-stale-csrfexempt-tests-in-webtest.md
- **Context:** Initial task creation

### 2026-04-23T19:26:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-803c2006
- **Timestamp:** 2026-06-02T14:57:16Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — No change to web/app.py csrf_protect (test fix only)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/app.py in: No change to web/app.py csrf_protect (test fix only)`
