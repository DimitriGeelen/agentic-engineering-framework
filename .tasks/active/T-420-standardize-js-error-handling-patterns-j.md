---
id: T-420
name: "Standardize JS error handling patterns (J4)"
description: >
  Create fetchWithError() helper for consistent error handling across all fetch calls. Currently inconsistent: some use .catch() with no logging, some chain .then().catch() with minimal feedback, some fail silently. Error messages vary: 'Cannot connect to LLM' vs 'Network error' vs bare 'error'. Directive score: J4=7. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: [refactoring, javascript, watchtower, reliability, usability]
components: [web/static/js/chat.js, web/static/js/search-qa.js]
related_tasks: [T-411]
created: 2026-03-10T21:03:20Z
last_update: 2026-03-11T07:46:52Z
date_finished: null
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
