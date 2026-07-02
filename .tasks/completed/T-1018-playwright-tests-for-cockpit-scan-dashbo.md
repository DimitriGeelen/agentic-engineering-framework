---
id: T-1018
name: "Playwright tests for cockpit scan dashboard — scan refresh, approve, defer,
  apply"
description: >
  Add Playwright regression tests for cockpit.py blueprint routes — scan dashboard,
  approval/deferral flows, focus actions

status: work-completed
workflow_type: test
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-07T11:19:41Z
last_update: '2026-06-11T22:23:37Z'
date_finished: 2026-04-07T11:23:15Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:37Z'
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

# T-1018: Playwright tests for cockpit scan dashboard — scan refresh, approve, defer, apply

## Context

Cockpit blueprint (`web/blueprints/cockpit.py`) has zero Playwright test coverage. It's the main landing page with scan dashboard, approval flows, and system health.

## Acceptance Criteria

### Agent
- [x] `tests/playwright/test_cockpit.py` exists with tests for cockpit page
- [x] Tests cover: page load, heading, scan meta, action summary, system health, test counts
- [x] Tests cover: API endpoints return expected status codes
- [x] All tests pass: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_cockpit.py -v`

## Verification

test -f tests/playwright/test_cockpit.py
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/playwright/test_cockpit.py -v

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

### 2026-04-07T11:19:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1018-playwright-tests-for-cockpit-scan-dashbo.md
- **Context:** Initial task creation

### 2026-04-07T11:23:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5b412b27
- **Timestamp:** 2026-06-02T14:54:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
