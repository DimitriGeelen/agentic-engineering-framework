---
id: T-420
name: "Standardize JS error handling patterns (J4)"
description: >
  Create fetchWithError() helper for consistent error handling across all fetch calls.
  Currently inconsistent: some use .catch() with no logging, some chain .then().catch()
  with minimal feedback, some fail silently. Error messages vary: 'Cannot connect
  to LLM' vs 'Network error' vs bare 'error'. Directive score: J4=7. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
components: [web/static/js/chat.js]
related_tasks: [T-411]
created: 2026-03-10T21:03:20Z
last_update: '2026-06-11T22:24:21Z'
date_finished: 2026-03-11T07:49:30Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 1
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-420: Standardize JS error handling patterns (J4)

## Context

Refactoring finding J4 (score 7) from `docs/reports/T-411-refactoring-directive-scoring.md`.

**J4 — Inconsistent error handling patterns:**
Multiple fetch calls with inconsistent error handling: some .catch() with no logging, some chain
.then().catch() with minimal feedback, some fail silently. Messages vary: 'Cannot connect to LLM'
vs 'Network error' vs bare 'error'. See research artifact § "JAVASCRIPT" row J4.
Files: chat.js:59-92,429-501; search-qa.js:305-331.

## Acceptance Criteria

### Agent
- [x] fetchWithError() or equivalent helper created
- [x] All fetch calls use consistent error handling
- [x] Error messages follow consistent pattern (what failed + what to do)
- [x] No silent fetch failures remain

### Human
<!-- No human verification needed for this refactoring -->

## Verification

grep -q 'fetchWithError\|handleFetchError' web/static/js/chat.js web/static/js/search-qa.js

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

### 2026-03-10T21:03:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-420-standardize-js-error-handling-patterns-j.md
- **Context:** Initial task creation

### 2026-03-11T07:46:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-11T07:49:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c128b03a
- **Timestamp:** 2026-06-02T15:02:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
