---
id: T-1343
name: "T-1337 B1+B2 — flip CSRF middleware to allowlist + add fetch() X-CSRF-Token helper"
description: >
  T-1337 B1+B2 — flip CSRF middleware to allowlist + add fetch() X-CSRF-Token helper

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-19T23:48:05Z
last_update: 2026-04-20T07:18:58Z
date_finished: 2026-04-20T07:18:58Z
---

# T-1343: T-1337 B1+B2 — flip CSRF middleware to allowlist + add fetch() X-CSRF-Token helper

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `web/app.py` `csrf_protect` no longer contains `request.path.startswith("/api/")` exemption
- [x] `web/templates/base.html` exposes `window.fetchWithCsrf(url, options)` helper that auto-attaches `X-CSRF-Token` to non-GET/HEAD
- [x] All state-mutating fetch() callers to `/api/*` (task_detail, tasks, sessions, cron) use `fetchWithCsrf` or set `X-CSRF-Token` explicitly
- [x] Watchtower restarts cleanly; `curl -sf http://localhost:3000/` returns 200
- [x] POST `/api/task/<id>/status` without token → 403; with token → 200 (smoke test)

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

### 2026-04-19T23:48:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1343-t-1337-b1b2--flip-csrf-middleware-to-all.md
- **Context:** Initial task creation

### 2026-04-20T07:18:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
