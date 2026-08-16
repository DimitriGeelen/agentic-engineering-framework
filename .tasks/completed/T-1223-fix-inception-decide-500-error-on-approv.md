---
id: T-1223
name: "Fix inception decide 500 error on approvals page"
description: >
  Fix inception decide 500 error on approvals page

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/inception.sh, web/blueprints/inception.py]
related_tasks: []
created: 2026-04-13T11:28:20Z
last_update: '2026-08-16T22:24:26Z'
date_finished: 2026-04-13T11:32:04Z
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

# T-1223: Fix inception decide 500 error on approvals page

## Context

All 5 inception decide buttons on /approvals return 500. The `fw inception decide` command runs but
returns non-zero exit code, causing the htmx response to be a 500 error. Need to identify and fix
the root cause of the CLI failure.

## Acceptance Criteria

### Agent
- [x] Root cause: captured → work-completed is invalid transition; fix adds captured → started-work step
- [x] All inception decide buttons on /approvals return 200 (confirmed via Playwright)
- [x] Playwright test confirms buttons work

## Verification

curl -sf http://localhost:3000/approvals > /dev/null

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

### 2026-04-13T11:28:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1223-fix-inception-decide-500-error-on-approv.md
- **Context:** Initial task creation

### 2026-04-13T11:32:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a1f3be92
- **Timestamp:** 2026-06-02T14:56:01Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/approvals > /dev/null`
