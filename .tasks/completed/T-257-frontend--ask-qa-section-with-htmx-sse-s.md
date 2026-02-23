---
id: T-257
name: "Frontend — Ask Q&A section with htmx SSE streaming"
description: >
  Add Ask Q&A section to web/templates/search.html: textarea input, Ask button, answer div with streaming token display, collapsible Sources panel with inline [1][2] citations. Uses htmx 2.0+ SSE extension (hx-ext=sse, sse-connect). Reuses T-253 URL mapping for source links. ~80 lines template + check/upgrade htmx version. See docs/reports/T-254-llm-assisted-qa-research.md RQ-3. Predecessor: T-256.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-254]
created: 2026-02-23T20:38:34Z
last_update: 2026-02-23T21:26:45Z
date_finished: 2026-02-23T21:01:32Z
---

# T-257: Frontend — Ask Q&A section with htmx SSE streaming

## Context

Frontend for LLM Q&A. See `docs/reports/T-254-llm-assisted-qa-research.md` RQ-3.

## Acceptance Criteria

### Agent
- [x] Ask section exists on search page with input and button
- [x] Connects to `/search/ask` SSE endpoint
- [x] Tokens stream into answer div in real-time
- [x] Sources panel shows after answer completes with numbered citations
- [x] Source links are clickable (reuses T-253 URL mapping)
- [x] Model name displayed during generation
- [x] Error messages displayed if LLM fails

### Human
- [x] Streaming UX feels responsive and natural
- [x] Answer formatting (markdown) is readable
- [x] Source panel layout is clean and useful

## Verification

# Search page loads with Ask section
curl -sf http://localhost:3000/search | grep -q "Ask"
# Ask section has SSE attributes
curl -sf http://localhost:3000/search | grep -q "sse"

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

### 2026-02-23T20:38:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-257-frontend--ask-qa-section-with-htmx-sse-s.md
- **Context:** Initial task creation

### 2026-02-23T21:01:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-23T21:01:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
