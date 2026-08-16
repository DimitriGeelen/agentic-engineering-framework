---
id: T-1233
name: "Fix Playwright test timeouts on /tasks and /timeline routes"
description: >
  Fix Playwright test timeouts on /tasks and /timeline routes

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-003, web/blueprints/tasks.py, web/blueprints/timeline.py, 
      web/shared.py]
related_tasks: []
created: 2026-04-13T18:32:45Z
last_update: '2026-08-16T22:24:26Z'
date_finished: 2026-04-13T18:40:47Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
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
  - ts: '2026-08-16T22:24:26Z'
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

# T-1233: Fix Playwright test timeouts on /tasks and /timeline routes

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] /tasks route responds within 5s (curl returns 200) — 0.05s warm, 5s cold
- [x] /timeline route responds within 5s (curl returns 200) — 0.3s warm, 2s cold
- [x] Playwright tests for /tasks and /timeline pass — all 27 response time tests pass
- [x] Root cause identified and documented — 2400+ file reads per request, fixed with TTL cache

### Human
<!-- No human ACs needed — all verifiable by agent.
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
curl -sf -o /dev/null -w "%{http_code}" http://localhost:3000/tasks | grep -q 200
curl -sf -o /dev/null -w "%{http_code}" http://localhost:3000/timeline | grep -q 200

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

### 2026-04-13T18:32:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1233-fix-playwright-test-timeouts-on-tasks-an.md
- **Context:** Initial task creation

### 2026-04-13T18:40:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** All Playwright response time tests pass. /tasks 99x faster, /timeline 7x faster, /graduation 77x faster.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3c25ca5f
- **Timestamp:** 2026-06-02T14:56:06Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf -o /dev/null -w "%{http_code}" http://localhost:3000/tasks | grep -q 200`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `curl -sf -o /dev/null -w "%{http_code}" http://localhost:3000/timeline | grep -q 200`
