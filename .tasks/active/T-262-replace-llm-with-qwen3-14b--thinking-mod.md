---
id: T-262
name: "Replace LLM with Qwen3-14B + thinking mode toggle"
description: >
  Replace qwen2.5-coder-32b IQ2_M (4.8 tok/s) with Qwen3-14B Q4_K_M (~33 tok/s). Add thinking mode toggle: simple queries use think=False, complex queries use think=True with 'Thinking...' UI indicator. Update web/ask.py model constants, add query complexity classifier, update frontend to show thinking phase. Ref: docs/reports/T-261-models-16gb-vram.md §Tier 1 #1, T-261-thinking-models.md §4 (Ollama config), §6 (hybrid approach). Predecessor: T-258 (model management). VRAM: 9.3GB model + 3-4GB KV cache = ~13GB. Prerequisite: ollama pull qwen3:14b on host.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [qa, llm, model]
components: []
related_tasks: []
created: 2026-02-24T08:36:31Z
last_update: 2026-02-24T08:36:31Z
date_finished: null
---

# T-262: Replace LLM with Qwen3-14B + thinking mode toggle

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking. -->
<!-- Remove this section if all criteria are agent-verifiable. -->

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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
