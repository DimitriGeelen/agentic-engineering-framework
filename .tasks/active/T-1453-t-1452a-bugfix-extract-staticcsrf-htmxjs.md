---
id: T-1453
name: "T-1452a Bugfix: extract static/csrf-htmx.js, share between base.html and review.html, add Playwright regression on /review/<id> mutation flow, audit other standalone templates"
description: >
  Build task spawned from T-1452 GO-structural-fix decision. Scope: (1) extract htmx:configRequest CSRF listener + fetchWithCsrf wrapper from web/templates/base.html:429-449 into web/static/csrf-htmx.js; (2) include the script from both base.html and web/templates/review.html via <script src=...>; (3) audit web/templates/*.html for other standalone templates (any HTML file with its own <head> block + hx-post/hx-put/hx-delete/hx-patch but no csrf listener) and fix; (4) Playwright test in tests/playwright/ that opens /review/<task_id>, ticks an AC checkbox, asserts the toggle-ac API returns 2xx + checkbox state persists; (5) capture L-269 if audit found additional victims; (6) consider filing v1.7 reviewer pattern candidate 'standalone-template-no-csrf'.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-25T11:51:34Z
last_update: 2026-04-25T11:51:34Z
date_finished: null
---

# T-1453: T-1452a Bugfix: extract static/csrf-htmx.js, share between base.html and review.html, add Playwright regression on /review/<id> mutation flow, audit other standalone templates

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
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

### 2026-04-25T11:51:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1453-t-1452a-bugfix-extract-staticcsrf-htmxjs.md
- **Context:** Initial task creation
