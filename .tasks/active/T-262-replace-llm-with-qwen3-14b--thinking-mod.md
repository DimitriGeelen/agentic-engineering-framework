---
id: T-262
name: "Replace LLM with Qwen3-14B + thinking mode toggle"
description: >
  Replace qwen2.5-coder-32b IQ2_M (4.8 tok/s) with Qwen3-14B Q4_K_M (~33 tok/s). Add thinking mode toggle: simple queries use think=False, complex queries use think=True with 'Thinking...' UI indicator. Update web/ask.py model constants, add query complexity classifier, update frontend to show thinking phase. Ref: docs/reports/T-261-models-16gb-vram.md §Tier 1 #1, T-261-thinking-models.md §4 (Ollama config), §6 (hybrid approach). Predecessor: T-258 (model management). VRAM: 9.3GB model + 3-4GB KV cache = ~13GB. Prerequisite: ollama pull qwen3:14b on host.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [qa, llm, model]
components: []
related_tasks: []
created: 2026-02-24T08:36:31Z
last_update: 2026-02-24T09:03:29Z
date_finished: null
---

# T-262: Replace LLM with Qwen3-14B + thinking mode toggle

## Context

Replace qwen2.5-coder-32b IQ2_M with Qwen3-14B. Ref: [T-261-thinking-models.md](../../docs/reports/T-261-thinking-models.md) §4,§6

## Acceptance Criteria

### Agent
- [x] PRIMARY_MODEL set to qwen3:14b
- [x] Query complexity classifier (should_think) routes simple vs complex queries
- [x] think=True/False passed to ollama.chat based on classifier
- [x] Thinking tokens streamed as separate SSE event type
- [x] Frontend shows "Thinking... (Ns)" indicator during thinking phase
- [x] Fallback model still works if qwen3:14b unavailable

### Human
- [ ] Answer quality noticeably better than old model
- [ ] Thinking mode activates appropriately (complex queries think, simple ones don't)
- [ ] Thinking indicator UX feels natural

## Verification

# Model constant updated
grep -q 'PRIMARY_MODEL = "qwen3:14b"' web/ask.py
# Thinking classifier exists
grep -q "should_think" web/ask.py
# Think parameter passed to ollama.chat
grep -q "think=use_thinking" web/ask.py
# Frontend handles thinking events
grep -q "thinking_done" web/templates/search.html
# Module loads correctly
python3 -c "from web.ask import should_think, PRIMARY_MODEL; assert PRIMARY_MODEL == 'qwen3:14b'; print('OK')"
# Classifier works
python3 -c "from web.ask import should_think; assert should_think('why does the healing agent fail?'); assert not should_think('what is T-042?'); print('OK')"

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

### 2026-02-24T08:36:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-262-replace-llm-with-qwen3-14b--thinking-mod.md
- **Context:** Initial task creation

### 2026-02-24T09:03:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
