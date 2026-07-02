---
id: T-990
name: "Playwright tests for directives and search pages"
description: >
  Playwright tests for directives and search pages

status: work-completed
workflow_type: test
owner: agent
horizon: null
components: [tests/playwright/test_directives.py, 
      tests/playwright/test_search.py]
related_tasks: []
created: 2026-04-07T08:26:34Z
last_update: '2026-06-11T22:24:34Z'
date_finished: 2026-04-07T08:28:40Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:34Z'
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

# T-990: Playwright tests for directives and search pages

## Context

/directives and /search nav routes lack Playwright regression tests. Completes full nav coverage.

## Acceptance Criteria

### Agent
- [x] test_directives.py covers directives page load, heading, and constitutional directive content
- [x] test_search.py covers search page load and search functionality
- [x] All new tests pass (8/8)
- [x] Fabric cards registered

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_directives.py tests/playwright/test_search.py -x -q 2>&1 | tail -5

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

### 2026-04-07T08:26:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-990-playwright-tests-for-directives-and-sear.md
- **Context:** Initial task creation

### 2026-04-07T08:28:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-acc970a7
- **Timestamp:** 2026-06-02T15:06:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
