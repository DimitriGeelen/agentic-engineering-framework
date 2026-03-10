---
id: T-410
name: "Chat provider health indicators: status lights and connection test button"
description: >
  Chat provider health indicators: status lights and connection test button

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: [watchtower, chat, llm, ux]
components: [web/static/js/chat.js, web/templates/_partials/chat_tab.html]
related_tasks: []
created: 2026-03-10T19:53:03Z
last_update: 2026-03-10T22:04:14Z
date_finished: 2026-03-10T19:56:14Z
---

# T-410: Chat provider health indicators: status lights and connection test button

## Context

Add health indicator dots (green/red) next to each provider in the Ask AI chat tab, and a "Test" button
that pings the active provider and shows latency. Uses existing `/api/v1/health` endpoint data.

## Acceptance Criteria

### Agent
- [x] Provider dropdown shows colored dot (green=available, red=offline) next to each option
- [x] "Test" button next to provider selector pings provider and shows latency in ms
- [x] Health dots update on tab activation (uses existing `/api/v1/health` data)
- [x] Test button shows error message when provider is unreachable

### Human
- [ ] [REVIEW] Health indicators look clean and informative in the chat UI
  **Steps:**
  1. Open http://localhost:3000/search
  2. Click "Ask AI" tab
  3. Check provider dropdown has colored dots
  4. Click "Test" button and verify latency appears
  **Expected:** Green dot next to Ollama, latency shown (e.g., "42ms")
  **If not:** Note which indicator is missing or broken

## Verification

grep -q "chat-health-dot" web/static/js/chat.js
grep -q "chatTestProvider" web/static/js/chat.js

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

### 2026-03-10T19:53:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-410-chat-provider-health-indicators-status-l.md
- **Context:** Initial task creation

### 2026-03-10T19:56:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next
