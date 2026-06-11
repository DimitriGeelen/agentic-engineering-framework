---
id: T-1604
name: "Fix 4 pre-existing Playwright failures: test_approvals decisions-vs-verifications,
  test_inception redecide+dedupe (T-1600 follow-up)"
description: >
  Fix 4 pre-existing Playwright failures: test_approvals decisions-vs-verifications,
  test_inception redecide+dedupe (T-1600 follow-up)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-29T18:48:39Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-29T19:40:00Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 5
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=5 
      (body:new-collab-mode); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1604: Fix 4 pre-existing Playwright failures: test_approvals decisions-vs-verifications, test_inception redecide+dedupe (T-1600 follow-up)

## Context

T-1600 full-suite Playwright run surfaced 4 pre-existing failures unrelated to the new interaction tests:

1. `test_approvals.py::TestDecisionsVsVerificationsSplit::test_section_headings_present_when_items_exist` — flaky-by-design: the `if "<h2" in content and "Decisions" in content` guard always fires (because the summary-bar `<a>...Decisions</a>` link contains the word "Decisions" and the page always has at least one `<h2>`), so the assertion runs even when no Decisions section is rendered.
2. `test_inception.py::TestRedecideAffordance::test_decided_inception_shows_superseding_form` — fixture `_find_decided_inception` lists `/inception?decision=go` without filtering by location, picks T-084 (completed), but the form template gates on `task._location == 'active'`.
3. `test_inception.py::TestRedecideAffordance::test_decided_inception_shows_context_note` — same fixture, same issue.
4. `test_inception.py::TestRecommendationDecisionDedupe::test_adopted_decision_collapses_recommendation` — fixture `_find_decided_adopted_inception` only checks GO inceptions; no active inception currently has GO decision (DEFER tasks are present though). Pinning to GO over-narrows the invariant — dedupe rendering applies to any adopted decision.

## Acceptance Criteria

### Agent
- [x] `_find_decided_inception` fixture filters to active inceptions and accepts any decided state (go|no-go|defer)
- [x] `_find_decided_adopted_inception` fixture filters to active inceptions and accepts any decided state with `adopted by human`
- [x] `test_section_headings_present_when_items_exist` uses regex match on `<h2 ...>Decisions</h2>` instead of substring contamination
- [x] All 4 previously-failing tests pass (or skip cleanly if state still unmet)
- [x] Full Playwright suite runs without these 4 failures

## Verification

bash -c 'timeout 60 python3 -m pytest tests/playwright/test_approvals.py::TestDecisionsVsVerificationsSplit::test_section_headings_present_when_items_exist tests/playwright/test_inception.py::TestRedecideAffordance::test_decided_inception_shows_superseding_form tests/playwright/test_inception.py::TestRedecideAffordance::test_decided_inception_shows_context_note tests/playwright/test_inception.py::TestRecommendationDecisionDedupe::test_adopted_decision_collapses_recommendation -v 2>&1 | tail -20'

## RCA

**Symptom:** 4 Playwright tests fail in the full suite while the targeted features work in production — both regression and fixture decay class.

**Root cause:** Fixture-state coupling without filtering. `_find_decided_inception` and `_find_decided_adopted_inception` were written when active GO inceptions existed. As tasks completed and got moved to `.tasks/completed/` over time, the fixtures started selecting completed tasks where the form-render template explicitly gates on `_location == 'active'`. The `test_section_headings_present_when_items_exist` test had a different but related bug — its "items exist" detector matched the summary-bar `<a>Decisions</a>` link text, not actual heading rendering.

**Why structurally allowed:** Playwright tests against live data are state-dependent by construction. There's no invariant that fixtures must filter to states their assertions assume — same class as L-324 (T-1598's static-fixture decay).

**Prevention:** Pattern — when a Playwright fixture iterates `/inception` (or any list view), ALWAYS pin filters to the test's intent (active/completed, decided state). When asserting "section X rendered", scope substring detection to the rendering envelope, not the whole page (e.g., `<h2 ...>Decisions</h2>` not bare "Decisions"). Captured as L-327.

## Recommendation

- **Recommendation:** GO
- **Rationale:** All 4 pre-existing failures resolved with minimal, targeted fixes. Two were fixture-state coupling bugs (missing `?location=active` filter); one was a test-logic bug (substring contamination from summary-bar link). All sibling tests in the same classes still pass. Captured as L-327.
- **Evidence:**
  - 4/4 target tests pass (was 0/4)
  - 8/8 tests across `TestDecisionsVsVerificationsSplit`, `TestRedecideAffordance`, `TestRecommendationDecisionDedupe` pass (no regression)
  - Files: `tests/playwright/test_approvals.py`, `tests/playwright/test_inception.py`
  - Learning: L-327 (fixture filter discipline)

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

### 2026-04-29T18:48:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1604-fix-4-pre-existing-playwright-failures-t.md
- **Context:** Initial task creation

### 2026-04-29T18:49:09Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: next → next

### 2026-04-29T19:35:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4e5e4d36
- **Timestamp:** 2026-06-02T14:58:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-29T19:40:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
