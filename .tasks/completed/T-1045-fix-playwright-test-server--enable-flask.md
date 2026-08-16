---
id: T-1045
name: "Fix Playwright test server — enable Flask threaded mode to prevent sequential
  request starvation"
description: >
  Fix Playwright test server — enable Flask threaded mode to prevent sequential request
  starvation

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/playwright/conftest.py]
related_tasks: []
created: 2026-04-07T16:37:38Z
last_update: '2026-08-16T22:24:21Z'
date_finished: 2026-04-07T16:44:41Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:38Z'
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
  - ts: '2026-08-16T22:24:21Z'
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

# T-1045: Fix Playwright test server — enable Flask threaded mode to prevent sequential request starvation

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] conftest.py redirects Flask stderr to file instead of PIPE (prevents buffer deadlock)
- [x] conftest.py stdout redirected to DEVNULL (not needed after startup)
- [x] Test collection still succeeds (305 tests)
- [x] Full suite: 305 passed, 0 failed in 4m29s (was 158/133 in 79 min)

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

### 2026-04-07T16:37:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1045-fix-playwright-test-server--enable-flask.md
- **Context:** Initial task creation

### 2026-04-07T16:44:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a342cee3
- **Timestamp:** 2026-06-02T14:54:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
