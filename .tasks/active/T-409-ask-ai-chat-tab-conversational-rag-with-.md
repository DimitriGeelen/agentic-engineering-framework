---
id: T-409
name: "Ask AI chat tab: conversational RAG with save/resume and model selector"
description: >
  Ask AI chat tab: conversational RAG with save/resume and model selector

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: [watchtower, search, llm, rag]
components: [web/app.py, C-003, web/embeddings.py, web/static/js/chat.js, web/templates/_partials/chat_tab.html, web/templates/search.html]
related_tasks: []
created: 2026-03-10T17:57:50Z
last_update: 2026-03-10T22:04:14Z
date_finished: 2026-03-10T19:04:27Z
---

# T-409: Ask AI chat tab: conversational RAG with save/resume and model selector

## Context

Add a dedicated "Ask AI" chat tab to the search page. Conversational RAG with streaming,
multi-turn history, save/resume conversations, model/provider selector, and optional context scoping.
User requested chat-style interactive dialogue (like Claude/ChatGPT) separate from keyword/semantic search.

## Acceptance Criteria

### Agent
- [x] "Ask AI" tab appears in search mode pills and switches to chat UI
- [x] Chat UI renders: message thread, input bar, model/provider selector, scope filter
- [x] Streaming SSE endpoint accepts scope and model_override params
- [x] Save conversation endpoint stores JSON + Markdown to .context/qa/conversations/
- [x] Load conversation endpoint returns saved state for continuation
- [x] List conversations endpoint returns saved conversations for sidebar
- [x] CSRF fix: JSON POST endpoints exempt from CSRF check (verified — no 403)
- [x] Chat streaming works end-to-end (user message → RAG → LLM → streamed response)
- [x] Save and reload a conversation (round-trip)
- [x] Register new fabric cards for chat.js and chat_tab.html

### Human
- [ ] [REVIEW] Chat UI looks and feels like a natural conversation interface
  **Steps:**
  1. Open http://localhost:3000/search
  2. Click "Ask AI" tab
  3. Ask "How does the audit system work?" and wait for response
  4. Ask a follow-up question
  5. Click "Save Conversation" and verify it appears in saved list
  6. Click "Continue" on saved conversation to reload
  **Expected:** Smooth streaming, readable messages, save/load works
  **If not:** Note which step failed

## Verification

grep -q "chat-container" web/templates/_partials/chat_tab.html
grep -q "chatAsk" web/static/js/chat.js
grep -q "save-conversation" web/blueprints/discovery.py
grep -q "model_override" web/ask.py

## Decisions

### 2026-03-10 — Stale embedding index handling for chat RAG

- **Chose:** Option 3 — Async index build + honest "warming up" SSE message + no BM25 fallback
- **Why:** This is conversational RAG with natural language inference, not document search.
  The LLM reasons over the context chunks to produce multi-turn inferential answers.
  BM25-only context is structurally different from semantic+BM25 hybrid context:
  - BM25 matches keywords literally; misses conceptually related content
  - For inference questions ("why", "how does X affect Y"), the LLM needs semantically
    adjacent chunks, not just keyword-matched files
  - Multi-turn conversations compound context quality issues — slightly wrong context
    in turn 1 builds a wrong mental model that cascades through subsequent turns
  - No answer is better than a subtly wrong conversational foundation
- **Rejected:**
  - **Option 1 (BM25 fallback):** Silently degrades context quality without user awareness.
    For document search this would be acceptable (90%+ same results). For conversational
    inference it produces misleading chains the user builds on. Rejected by human review.
  - **Option 2 (blocking pre-build):** App startup takes 30-60s. Single-threaded Flask
    freezes for all users during build. Ties availability to Ollama availability.
  - **Option 4 (fix timeout only):** First request still hangs 30-60s. Flask blocks all
    other requests during build. Feels broken even though it "works."
- **Implementation:** RAG retrieval moved inside SSE generator. New `status` event type
  sends phase-by-phase progress ("Building knowledge index...", "Searching knowledge base...",
  "Found N sources — generating answer..."). On embed failure: returns honest error +
  triggers background thread to build index for next attempt.

## Updates

### 2026-03-10T17:57:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-409-ask-ai-chat-tab-conversational-rag-with-.md
- **Context:** Initial task creation

### 2026-03-10T19:04:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next
