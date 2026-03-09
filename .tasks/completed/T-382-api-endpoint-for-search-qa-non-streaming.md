---
id: T-382
name: "API endpoint for search Q&A (non-streaming JSON)"
description: >
  API endpoint for search Q&A (non-streaming JSON)

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [api, search]
components: []
related_tasks: []
created: 2026-03-09T10:36:44Z
last_update: 2026-03-09T10:42:47Z
date_finished: 2026-03-09T10:42:47Z
---

# T-382: API endpoint for search Q&A (non-streaming JSON)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] web/blueprints/api.py created with /api/v1/ask, /api/v1/search, /api/v1/health
- [x] Blueprint registered in app.py
- [x] CSRF exempted for /api/ routes
- [x] /api/v1/health returns 200 with provider info
- [x] /api/v1/search returns JSON results

## Verification

curl -sf http://localhost:3000/api/v1/health | python3 -c "import sys,json; assert json.load(sys.stdin)['status']=='ok'"
curl -sf "http://localhost:3000/api/v1/search?q=healing&mode=keyword" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['total']>0"

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

### 2026-03-09T10:36:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-382-api-endpoint-for-search-qa-non-streaming.md
- **Context:** Initial task creation

### 2026-03-09T10:42:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
