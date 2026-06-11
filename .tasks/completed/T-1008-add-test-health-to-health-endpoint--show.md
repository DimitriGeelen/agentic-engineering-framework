---
id: T-1008
name: "Add test health to /health endpoint — show Playwright/unit/web test counts"
description: >
  Add test health to /health endpoint — show Playwright/unit/web test counts

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-07T10:14:32Z
last_update: '2026-06-11T22:23:37Z'
date_finished: 2026-04-07T10:17:09Z
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

# T-1008: Add test health to /health endpoint — show Playwright/unit/web test counts

## Context

Enhance /health endpoint with test infrastructure counts — how many test files and test functions exist per suite (Playwright, unit, web). Helps monitor test health.

## Acceptance Criteria

### Agent
- [x] /health endpoint includes `tests` section with file counts per suite (playwright:27, unit:58, integration:69, web:1)
- [x] Playwright test for /health endpoint verifying test data presence (4 tests)
- [x] All tests pass

## Verification

cd /opt/999-Agentic-Engineering-Framework && curl -sf http://localhost:3000/health | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'tests' in d, 'missing tests key'; print('OK:', d['tests'])"

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

### 2026-04-07T10:14:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1008-add-test-health-to-health-endpoint--show.md
- **Context:** Initial task creation

### 2026-04-07T10:17:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-830c5fe8
- **Timestamp:** 2026-06-02T14:54:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
