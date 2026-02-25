---
id: T-268
name: "Multi-turn Q&A conversation"
description: >
  Add chat history to Q&A. Client-side history array sent via POST body. Switch from EventSource (GET-only) to fetch + ReadableStream for SSE consumption. Modify stream_answer() to accept history parameter (last 6 turns). Context window management: system prompt (~200 tokens) + RAG context (~3000) + 3 exchanges (~2000) = ~5200 tokens. Frontend: conversation thread display, 'New conversation' button, follow-up input. Ref: docs/reports/T-261-arch-improvements.md §1 (full architecture design, code sketches for both Python and JS). Predecessor: T-256 (endpoint), T-257 (frontend). Note: EventSource→fetch is a one-way door — changes SSE client code significantly.

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: [qa, frontend, chat]
components: [C-003, web/templates/search.html]
related_tasks: [T-256, T-257, T-261]
created: 2026-02-24T08:37:50Z
last_update: 2026-02-25T20:37:12Z
date_finished: 2026-02-25T07:21:39Z
---

# T-268: Multi-turn Q&A conversation

## Context

Multi-turn Q&A conversation — EventSource→fetch one-way door. Ref: docs/reports/T-261-arch-improvements.md §1.

## Acceptance Criteria

### Agent
- [x] stream_answer() accepts history parameter (list of {role, content} dicts)
- [x] History truncated to last 6 turns (3 exchanges) for context window management
- [x] /search/ask supports POST with JSON body {query, history}
- [x] GET /search/ask still works (backward compatible)
- [x] Frontend uses fetch+ReadableStream instead of EventSource
- [x] Client-side _conversationHistory array tracks conversation state
- [x] Conversation thread displays previous Q&A turns
- [x] New Conversation button clears history and thread
- [x] Follow-up questions sent with full conversation history
- [x] AbortController replaces EventSource.close() for request cancellation

### Human
- [x] Multi-turn answers reference prior conversation context naturally
- [x] Conversation thread is readable and well-formatted
- [x] New Conversation button resets cleanly

## Verification

# stream_answer accepts history parameter
grep -q "def stream_answer.*history" web/ask.py
# History truncation logic
grep -q "MAX_HISTORY_TURNS" web/ask.py
# POST method on /search/ask
grep -q 'methods=\["GET", "POST"\]' web/blueprints/discovery.py
# History extracted from POST body
grep -q "history.*data.get" web/blueprints/discovery.py
# Frontend uses fetch instead of EventSource
grep -q "fetch.*search/ask" web/templates/search.html
# Conversation history array exists
grep -q "_conversationHistory" web/templates/search.html
# New Conversation function exists
grep -q "function newConversation" web/templates/search.html
# AbortController for request cancellation
grep -q "AbortController" web/templates/search.html
# Module imports correctly
python3 -c "from web.ask import stream_answer; print('OK')"

## Decisions

### 2026-02-25 — SSE transport
- **Chose:** fetch+ReadableStream with POST body for SSE consumption
- **Why:** EventSource only supports GET (no request body for history). fetch+ReadableStream allows POST with JSON body while still reading SSE stream.
- **Rejected:** EventSource with history in query params (URL length limits), server-side session storage (adds server state complexity)

## Updates

### 2026-02-24T08:37:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-268-multi-turn-qa-conversation.md
- **Context:** Initial task creation

### 2026-02-25T07:06:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-25T07:21:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
