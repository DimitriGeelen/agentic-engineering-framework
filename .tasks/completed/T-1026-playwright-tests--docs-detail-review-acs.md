---
id: T-1026
name: "Playwright tests — docs detail, review ACs, POST error handling"
description: >
  Playwright tests — docs detail, review ACs, POST error handling

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-07T12:29:39Z
last_update: '2026-06-11T22:23:38Z'
date_finished: 2026-04-07T12:33:53Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:38Z'
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

# T-1026: Playwright tests — docs detail, review ACs, POST error handling

## Context

Continues T-1025 Playwright expansion. Covers docs detail pages, review ACs htmx fragment, and POST endpoint error handling. Total coverage target: 230+ tests.

## Acceptance Criteria

### Agent
- [x] test_docs_detail.py — /docs/generated/<card_name> detail page (4 tests)
- [x] test_review_acs.py — /review/<task_id>/acs AC fragment (3 tests)
- [x] test_api_task_mutations.py — POST error handling: create, horizon, status (5 tests)
- [x] test_api_healing.py — /api/healing/<task_id> POST validation (2 tests)
- [x] All 14 new tests pass

## Verification

ls tests/playwright/test_docs_detail.py tests/playwright/test_review_acs.py tests/playwright/test_api_task_mutations.py tests/playwright/test_api_healing.py
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_docs_detail.py tests/playwright/test_review_acs.py tests/playwright/test_api_task_mutations.py tests/playwright/test_api_healing.py -x -q 2>&1 | tail -5

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

### 2026-04-07T12:29:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1026-playwright-tests--docs-detail-review-acs.md
- **Context:** Initial task creation

### 2026-04-07T12:33:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2dfe4a9f
- **Timestamp:** 2026-06-02T14:54:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
