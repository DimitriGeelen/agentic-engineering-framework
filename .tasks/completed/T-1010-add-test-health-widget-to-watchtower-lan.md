---
id: T-1010
name: "Add test health widget to Watchtower landing page — show test counts from /health"
description: >
  Add test health widget to Watchtower landing page — show test counts from /health

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/playwright/conftest.py, tests/playwright/test_core.py, 
      tests/playwright/test_health.py, web/app.py, web/blueprints/cockpit.py, 
      web/templates/cockpit.html]
related_tasks: []
created: 2026-04-07T10:17:31Z
last_update: '2026-08-16T22:24:20Z'
date_finished: 2026-04-07T10:24:46Z
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
  - ts: '2026-08-16T22:24:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1010: Add test health widget to Watchtower landing page — show test counts from /health

## Context

Add test infrastructure counts to the System Health section of the Watchtower landing page. Data comes from /health endpoint (T-1008).

## Acceptance Criteria

### Agent
- [x] Landing page System Health section shows test file counts
- [x] Test counts display correctly (Playwright, unit, integration, web)
- [x] Playwright test verifies test counts appear on landing page
- [x] /health endpoint Ollama check has 3s timeout (prevents test infrastructure from hanging)
- [x] conftest.py handles 503 health response (Ollama unreachable but app healthy)

## Verification

cd /opt/999-Agentic-Engineering-Framework && curl -sf http://localhost:3000/ -o /tmp/wt-landing.html && grep -q "playwright" /tmp/wt-landing.html

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

### 2026-04-07T10:17:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1010-add-test-health-widget-to-watchtower-lan.md
- **Context:** Initial task creation

### 2026-04-07T10:24:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8e794385
- **Timestamp:** 2026-06-02T14:54:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
