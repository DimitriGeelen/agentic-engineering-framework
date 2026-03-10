---
id: T-409
name: "Ask AI chat tab: conversational RAG with save/resume and model selector"
description: >
  Ask AI chat tab: conversational RAG with save/resume and model selector

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [watchtower, search, llm, rag]
components: []
related_tasks: []
created: 2026-03-10T17:57:50Z
last_update: 2026-03-10T18:07:38Z
date_finished: null
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
- [ ] CSRF fix: JSON POST endpoints exempt from CSRF check (committed but untested)
- [ ] Chat streaming works end-to-end (user message → RAG → LLM → streamed response)
- [ ] Save and reload a conversation (round-trip)
- [ ] Register new fabric cards for chat.js and chat_tab.html

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

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-03-10T17:57:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-409-ask-ai-chat-tab-conversational-rag-with-.md
- **Context:** Initial task creation
