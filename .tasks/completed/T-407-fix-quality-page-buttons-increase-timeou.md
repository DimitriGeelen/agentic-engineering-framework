---
id: T-407
name: "Fix quality page buttons: increase timeouts, add loading feedback"
description: >
  Fix quality page buttons: increase timeouts, add loading feedback

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [watchtower, ux, bugfix]
components: []
related_tasks: []
created: 2026-03-10T14:10:26Z
last_update: '2026-08-16T22:25:30Z'
date_finished: 2026-03-10T14:14:26Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-407: Fix quality page buttons: increase timeouts, add loading feedback

## Context

Quality page buttons (Run Audit, Run Tests, Full Check) appeared non-functional: audit subprocess timeout (60s) was shorter than actual runtime (~102s), and spinner elements used `display:none` which conflicted with htmx indicator mechanism.

## Acceptance Criteria

### Agent
- [x] Audit subprocess timeout increased (60s → 180s)
- [x] Test subprocess timeout increased (120s → 300s)
- [x] Buttons show Pico.css loading spinner (aria-busy) during request
- [x] Buttons are disabled during request (hx-disabled-elt)
- [x] Run Audit button successfully completes and swaps results

### Human
- [x] [REVIEW] Quality page buttons work in browser
  **Steps:**
  1. Open http://localhost:3000/quality
  2. Click "Run Audit" — button should show spinner, become disabled
  3. Wait ~2 min — results should refresh with new timestamp
  4. Click "Run Tests" — same loading behavior
  **Expected:** Buttons show loading state and results update after completion
  **If not:** Check browser console for htmx errors

## Verification

curl -sf http://localhost:3000/quality > /dev/null
grep -q 'hx-disabled-elt="this"' web/templates/quality.html
grep -q "aria-busy" web/templates/quality.html
grep -q "timeout=180" web/blueprints/quality.py
grep -q "timeout=300" web/blueprints/quality.py

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

### 2026-03-10T14:10:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-407-fix-quality-page-buttons-increase-timeou.md
- **Context:** Initial task creation

### 2026-03-10T14:14:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-914f1671
- **Timestamp:** 2026-06-02T15:02:39Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/quality > /dev/null`

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#1 (Human)
