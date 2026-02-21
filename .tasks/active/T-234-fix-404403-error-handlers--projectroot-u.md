---
id: T-234
name: "Fix 404/403 error handlers — project_root undefined in base.html"
description: >
  Fix 404/403 error handlers — project_root undefined in base.html

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-02-21T20:44:57Z
last_update: 2026-02-21T20:44:57Z
date_finished: null
---

# T-234: Fix 404/403 error handlers — project_root undefined in base.html

## Context

The `_error_context()` function in `web/app.py` provides template context for 403/404 error handlers but was missing `project_root`. Since `base.html` references `{{ project_root }}` in the footer, every error page crashed with a Jinja2 `UndefinedError`, turning 404s into 500s. Additionally, `PROJECT_ROOT` was not imported at module level.

## Acceptance Criteria

### Agent
- [x] `_error_context()` includes `project_root` in returned dict
- [x] `PROJECT_ROOT` imported at module level in `web/app.py`
- [x] 404 pages return HTTP 404 (not 500)
- [x] Homepage still returns HTTP 200

## Verification

curl -s http://localhost:3000/nonexistent-page -o /dev/null -w "%{http_code}" | grep -q "404"
curl -sf http://localhost:3000/ -o /dev/null -w "%{http_code}" | grep -q "200"

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

### 2026-02-21T20:44:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-234-fix-404403-error-handlers--projectroot-u.md
- **Context:** Initial task creation
