---
id: T-1223
name: "Fix inception decide 500 error on approvals page"
description: >
  Fix inception decide 500 error on approvals page

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-13T11:28:20Z
last_update: 2026-04-13T11:28:20Z
date_finished: null
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
