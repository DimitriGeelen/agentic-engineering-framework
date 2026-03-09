---
id: T-377
name: "LLM Provider abstraction layer with Ollama + OpenRouter"
description: >
  Create web/llm/ package with LLMProvider ABC, OllamaProvider, OpenRouterProvider, ProviderManager. Strategy pattern for hot-switching. Refactor ask.py to use provider interface. Add openai dependency. Parent: T-375.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: [llm, openrouter]
components: []
related_tasks: []
created: 2026-03-09T09:41:38Z
last_update: 2026-03-09T09:51:06Z
date_finished: 2026-03-09T09:51:06Z
---

# T-377: LLM Provider abstraction layer with Ollama + OpenRouter

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] web/llm/ package created with provider.py, ollama_provider.py, openrouter_provider.py, manager.py
- [x] LLMProvider ABC with chat_stream, list_models, is_available
- [x] ask.py refactored to use provider abstraction (no direct ollama import)
- [x] ProviderManager supports hot-switching and lazy OpenRouter registration
- [x] All search/ask tests pass (36/36)

## Verification

python3 -c "from web.llm import get_manager; m = get_manager(); print(m.active_name, len(m.list_providers()))"
python3 -c "from web.ask import stream_answer, get_model; print('OK')"

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

### 2026-03-09T09:41:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-377-llm-provider-abstraction-layer-with-olla.md
- **Context:** Initial task creation

### 2026-03-09T09:47:37Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-09T09:51:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
