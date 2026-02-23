---
id: T-258
name: "Model management — pre-load and fallback logic"
description: >
  Add model management to the Ask endpoint: pre-load qwen2.5-coder-32b on Watchtower startup (ollama pull/warm), detect if model unavailable or GPU memory <2GB, auto-fallback to dolphin-llama3:8b. Unload unused model to free VRAM. ~30 lines. See docs/reports/T-254-llm-assisted-qa-research.md RQ-4. Predecessor: T-256.

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-254]
created: 2026-02-23T20:38:50Z
last_update: 2026-02-23T20:56:33Z
date_finished: 2026-02-23T20:56:33Z
---

# T-258: Model management — pre-load and fallback logic

## Context

Model selection + fallback for T-256. See `docs/reports/T-254-llm-assisted-qa-research.md` RQ-4.

## Acceptance Criteria

### Agent
- [x] Primary model: `krith/qwen2.5-coder-32b-instruct:IQ2_M`
- [x] Fallback model: `dolphin-llama3:8b`
- [x] `get_model()` function detects available models and selects best
- [x] Graceful error if no ollama models available
- [x] Model config importable: `from web.ask import get_model`

## Verification

python3 -c "from web.ask import get_model; m = get_model(); print(f'Model: {m}')"

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

### 2026-02-23T20:38:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-258-model-management--pre-load-and-fallback-.md
- **Context:** Initial task creation

### 2026-02-23T20:56:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-23T20:56:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
