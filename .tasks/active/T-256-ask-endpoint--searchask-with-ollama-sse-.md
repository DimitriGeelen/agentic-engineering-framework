---
id: T-256
name: "Ask endpoint — /search/ask with ollama SSE streaming"
description: >
  Create /search/ask Flask endpoint: retrieve 10 chunks via rag_retrieve() (T-255), format as numbered Markdown context, call ollama.chat(stream=True) with qwen2.5-coder-32b, yield SSE events (data: {token}). Include system prompt instructing LLM to cite sources as [1][2]. Fallback to dolphin-llama3:8b if primary unavailable. ~100 lines. See docs/reports/T-254-llm-assisted-qa-research.md RQ-1 + RQ-2. Predecessor: T-255.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-254]
created: 2026-02-23T20:38:18Z
last_update: 2026-02-23T20:57:43Z
date_finished: 2026-02-23T20:55:55Z
---

# T-256: Ask endpoint — /search/ask with ollama SSE streaming

## Context

SSE streaming endpoint for LLM Q&A. See `docs/reports/T-254-llm-assisted-qa-research.md` RQ-1 + RQ-2.

## Acceptance Criteria

### Agent
- [x] `/search/ask` endpoint exists in discovery blueprint
- [x] Retrieves chunks via `rag_retrieve()` (T-255)
- [x] Formats numbered Markdown context for LLM
- [x] Streams tokens via SSE (`text/event-stream`)
- [x] System prompt instructs LLM to cite sources as [1][2]
- [x] Sends source metadata as final SSE event
- [x] Handles ollama connection errors gracefully

### Human
- [ ] Answer quality is acceptable for framework questions
- [ ] Streaming feels responsive (first token visible quickly)

## Verification

# Endpoint returns SSE content-type
curl -sf -o /dev/null -w '%{content_type}' 'http://localhost:3000/search/ask?q=error+handling' | grep -q 'text/event-stream'
# Python import of ask module works
python3 -c "from web.ask import format_rag_context; print('OK')"

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

### 2026-02-23T20:38:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-256-ask-endpoint--searchask-with-ollama-sse-.md
- **Context:** Initial task creation

### 2026-02-23T20:55:55Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-23T20:55:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
