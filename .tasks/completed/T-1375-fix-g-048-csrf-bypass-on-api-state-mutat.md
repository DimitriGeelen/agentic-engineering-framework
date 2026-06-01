---
id: T-1375
name: "Fix G-048 CSRF bypass on /api/ state-mutating endpoints"
description: >
  Fix G-048 CSRF bypass on /api/ state-mutating endpoints

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-21T07:57:33Z
last_update: 2026-04-21T07:59:21Z
date_finished: 2026-04-21T07:59:21Z
---

# T-1375: Fix G-048 CSRF bypass on /api/ state-mutating endpoints

## Context

G-048 reported 2026-04-19 — `/api/*` blanket CSRF skip allowed unauthenticated state-mutating POSTs. On scoping this build task, discovered T-1343 (2026-04-20) already landed the fix: web/app.py:92-111 flipped to allowlist, only /health and JSON search paths skip CSRF. Client-side fetchWithCsrf() helper added. T-1344 retrofitted playwright conftest. The concern record was never updated to `mitigated` — stale watch entry.

## Acceptance Criteria

### Agent
- [x] Verified csrf_protect allowlist is in place (web/app.py:92-111)
- [x] curl -X POST /api/session/init without token → 403
- [x] curl -X POST /api/healing/T-1 without token → 403
- [x] curl -X POST /api/task/T-1/status without token → 403
- [x] curl -X DELETE /api/sessions/foo without token → 403
- [x] G-048 updated to `status: mitigated` with mitigation_applied evidence in concerns.yaml
- [x] G-048 related_tasks expanded with [T-1343, T-1344, T-1375]

## Verification

grep -q "T-1343 / G-048" web/app.py
test "$(curl -s -X POST http://localhost:3000/api/session/init -o /dev/null -w '%{http_code}')" = "403"
grep -q "status: mitigated" .context/project/concerns.yaml

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

### 2026-04-21T07:57:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1375-fix-g-048-csrf-bypass-on-api-state-mutat.md
- **Context:** Initial task creation

### 2026-04-21T07:59:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
