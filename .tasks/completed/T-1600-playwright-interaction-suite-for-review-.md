---
id: T-1600
name: "Playwright interaction suite for review surfaces — click flows, forced-500
  toast, mobile viewports"
description: >
  Extends tests/playwright/ with real interaction tests that DOM-grep can't cover:
  click GO/DEFER buttons end-to-end, force a 500 to verify the htmx error toast (T-1582
  closure), inception decide flow (open/fill rationale/submit/verify), mobile viewport
  snapshots for /cockpit /approvals /review. Surfaced by T-1597 sweep where W1-W5
  used curl+grep — closes the [REVIEW] subjective gap that grep can't reach.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-29T07:47:05Z
last_update: '2026-08-16T22:24:38Z'
date_finished: 2026-04-29T18:49:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
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
  - ts: '2026-08-16T22:24:38Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1600: Playwright interaction suite for review surfaces — click flows, forced-500 toast, mobile viewports

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `tests/playwright/test_review_interaction.py` exists with click-flow tests for `/review/<id>` GO/DEFER/NO-GO buttons — pins click-to-form contract via synthesized HTML + `page.route()` interception (5 tests: 1 AC checkbox, 3 decide buttons, 1 build complete). Note: real `showToast` only fires on errors, not success; success path is verified via captured POST URL + payload, which is the actual structural contract.
- [x] `tests/playwright/test_inception_decide_flow.py` exists covering the navigation journey `/approvals` → `/review/<id>` for inception tasks; fills rationale + clicks GO with route-intercepted POST (3 tests; 2 skip when no inception is in decide-ready state, which is the correct behaviour)
- [x] `tests/playwright/test_htmx_error_toast.py` exercises forced-500 via `page.route()`, asserts `<div class="wt-toast error">` renders + has non-empty text (2 tests). Closes the [REVIEW] gap that grep proved insufficient for (T-1582).
- [x] `tests/playwright/test_mobile_viewport.py` covers `/cockpit`, `/approvals`, `/review/<id>` at 375x667 — asserts no horizontal overflow (`scrollWidth <= clientWidth + 1px`) plus verdict-pill / recommendation-block visibility (5 tests)
- [x] All new tests pass: `fw test playwright -- tests/playwright/test_review_interaction.py tests/playwright/test_inception_decide_flow.py tests/playwright/test_htmx_error_toast.py tests/playwright/test_mobile_viewport.py` → 13 passed, 2 skipped (state-dependent)
- [x] No regression caused by new tests: full `fw test playwright` produces 4 pre-existing failures (test_approvals.py::TestDecisionsVsVerificationsSplit, test_inception.py::TestRedecideAffordance ×2, test_inception.py::TestRecommendationDecisionDedupe). Verified pre-existing by running each on master with my new files stashed — same 4 failures, same shape. Captured as follow-up T-1604 (separate task; orthogonal to this ticket's scope).

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

bin/fw test playwright -- tests/playwright/test_review_interaction.py tests/playwright/test_inception_decide_flow.py tests/playwright/test_htmx_error_toast.py tests/playwright/test_mobile_viewport.py

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Decisions

### 2026-04-29 — synthetic HTML vs live-state for click-flow tests
- **Chose:** Synthesized form HTML loaded via `page.set_content()` for the decide/complete click-flow tests; navigation tests use real `/approvals` walk
- **Why:** No inception task is currently in decide-ready state, and creating one mutates real `.tasks/` state. Synthesized HTML pins the click-to-form contract independent of which task is in which state. The navigation test (`test_inception_decide_flow.py::test_full_decide_journey_posts_to_correct_endpoint`) covers cross-surface integration when a fixture exists, otherwise skips.
- **Rejected:** Creating a synthetic test task on disk in setup — risk of leaving stale `.tasks/active/T-9999` files if teardown fails; pollutes the real index that `fw task list` reads.

### 2026-04-29 — success toast claim in original AC
- **Chose:** Verify success path via captured POST URL + payload, not toast presence
- **Why:** The actual `showToast` JS only fires from the `htmx:responseError` and `htmx:sendError` handlers (review.html:553-559). On success, htmx swaps the target element in place — there is no success toast. The AC's "verifies success toast appears" was based on an inaccurate read of the template; the real structural contract is "POST fires to the right endpoint with the right payload."
- **Rejected:** Adding a success toast to make the original AC literal — unnecessary scope creep; the navigation chain already gives the human signal (the form replaces with the success state).

## Recommendation

**Recommendation:** GO
**Rationale:** All 4 new test files exist with focused click-flow / forced-error / mobile-viewport coverage; 13 tests pass + 2 correctly skip on state-dependent fixtures. Closes the [REVIEW]-only gap surfaced by T-1597 — DOM-grep tests can't catch click regressions, and these tests catch them. Mobile-viewport overflow detection now structural (was [REVIEW]-only).
**Evidence:**
- `tests/playwright/test_review_interaction.py` — 5 tests covering AC checkbox + GO/NO-GO/DEFER + Complete buttons
- `tests/playwright/test_inception_decide_flow.py` — 3 tests for /approvals → /review navigation chain
- `tests/playwright/test_htmx_error_toast.py` — 2 tests for forced-500 toast contract (closes T-1582 [REVIEW])
- `tests/playwright/test_mobile_viewport.py` — 5 tests for /cockpit, /approvals, /review at 375x667
- Combined run: `13 passed, 2 skipped in 18.31s`
- 1 Decision recorded explaining the success-toast scope adjustment

## Updates

### 2026-04-29T07:47:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1600-playwright-interaction-suite-for-review-.md
- **Context:** Initial task creation

### 2026-04-29T07:51:18Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-29T18:34:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7dba3822
- **Timestamp:** 2026-06-02T14:58:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-29T18:49:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
