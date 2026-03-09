---
id: T-384
name: "Add SSE streaming endpoint and OpenAPI docs to REST API"
description: >
  Add SSE streaming endpoint and OpenAPI docs to REST API

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [api, docs]
components: []
related_tasks: []
created: 2026-03-09T10:55:38Z
last_update: 2026-03-09T10:57:35Z
date_finished: 2026-03-09T10:57:35Z
---

# T-384: Add SSE streaming endpoint and OpenAPI docs to REST API

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] /api/v1/ returns self-documenting index with all endpoints
- [x] /api/v1/ask/stream returns SSE stream (reuses stream_answer from ask.py)
- [x] Index includes examples, params, and event types for each endpoint

## Verification

curl -sf http://localhost:3000/api/v1/ | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'ask_stream' in d['endpoints']"
curl -sf http://localhost:3000/api/v1/ | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['name']=='Watchtower API'"

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

### 2026-03-09T10:55:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-384-add-sse-streaming-endpoint-and-openapi-d.md
- **Context:** Initial task creation

### 2026-03-09T10:57:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
